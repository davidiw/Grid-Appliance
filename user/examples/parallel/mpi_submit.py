#!/usr/bin/python

import sys, os, subprocess, shutil, time, xmlrpclib

from callback_serv import CallbackServ
from template_file import TemplateFile
from condor_mpi_util import *
from optparse import OptionParser
from threading import Thread

DEBUG = 1
PORT = 32603                                   # server listening port
SUBM_FNAME = 'submit_mpi_vanilla'              # submission template file name
CLNT_FNAME = 'condor_mpi_client.tmp.py'        # client-side script template
AUTH_FNAME = 'authorized_keys'
LOCAL_NFS_DIR = '/mnt/local'

FNULL = open('/dev/null', 'w')

class MPISubmission():

    def __init__(self, np, execfname ):
        self.debug = DEBUG
        self.np = np
        self.mpdPort = ''
        self.execfname = execfname
        self.servthread = None
        self.rand = genRandom()
        self.tmpPath = self._create_tmpdir()
        self.submitFile = TemplateFile( '' , SUBM_FNAME, self.tmpPath, 
                                        SUBM_FNAME + '_' + self.rand )
        self.clientFile = TemplateFile( '' , CLNT_FNAME, self.tmpPath, 
                                        CLNT_FNAME + '_' + self.rand )
        self.hostfname = self.tmpPath + 'hosts_' + self.rand
        self.keyfname = self.tmpPath + self.rand + '.key'
        self.hostlist = []             # store a list of [username, ip, port]

    # remove tmp dir and all its content
    def _rm_tmpdir(self, dst='.'):
        tpath = dst + '/tmp' + self.rand
        try:
            if os.access( tpath, os.F_OK) == True:
                shutil.rmtree( tpath )
        except os.error as e:
            sys.exit('Error: cannot remove temp directory - ' + e )

    def _create_tmpdir(self, dst='.'):
        try:
            os.makedirs( dst + '/tmp' + self.rand )
        except os.error as e:
            sys.exit('Error: cannot create temp directory - ' + e )
        return 'tmp' + self.rand + '/'

    def _start_mpd(self):
        # make sure no other mpds are running
        subprocess.call( 'mpdallexit', stdout=FNULL, stderr=FNULL)
        time.sleep(1.0)        # wait for old mpd ring to be torn down

        # starting server's mpd
        mpdconf_path = os.getcwd()+'/'+self.tmpPath[:-1]
        createMpdConf( self.rand, mpdconf_path )
        subprocess.Popen(['mpd'], env={ 'MPD_CONF_FILE': mpdconf_path+'/.mpd.conf' })
        time.sleep(1.0)         # wait for mpd to fully start

        # determine mpd listening port from mpdtrace output
        process = subprocess.Popen(['mpdtrace', '-l'], stdout=subprocess.PIPE)
        process.wait()
        traceout = process.communicate()[0]
        port = extractPort(traceout)

        if not port.isdigit(): 
            sys.exit('Error starting mpd : ' + traceout )
        self.mpdPort = port

    def start(self):

        # Copy exe file into local ganfs directory
        self._create_tmpdir( LOCAL_NFS_DIR )
        shutil.copy2( self.execfname, LOCAL_NFS_DIR + '/' + self.tmpPath )
        
        self._start_mpd()                     # start local mpd
        self._prepare_submission_files()      # prepare client script and condor submit file
        self._gen_ssh_keys()                  # generate ssh key pairs

        # start a listening server
        self.servthread = Thread( target=CallbackServ(self.np - 1, self.hostfname, PORT).serv )
        self.servthread.setDaemon(True)
        self.servthread.start()

        if self.debug:
            print "submit condor with file " + str(self.submitFile)

        p = subprocess.call(['condor_submit', str(self.submitFile) ] )
        if p != 0:
            sys.exit('Error: condor_submit return ' + str(p))

        # if the submission is successful, wait for the server 
        print 'Waiting for ' + str(self.np-1) + ' workers to response ....',
        sys.stdout.flush()
        self.servthread.join()
        print 'finished'
        self._read_hosts_info()        # read info from the collected hosts

        # Waiting for mpd ring to be ready
        limit = 10
        retry = 0
        while retry < limit :
            time.sleep(1.0)                # wait

            # testing mpd connection
            process = subprocess.Popen(['mpdtrace', '-l'], stdout=subprocess.PIPE )
            process.wait()
            trace = process.communicate()[0]
            retry += 1

            port = extractPort(trace)
            num = len( trace.split('\n') )

            if port.isdigit() and (num == self.np + 1):
                if self.debug:
                    print '\nMPD trace:\n' + trace
                break

        # Check whether mpdtrace return enough mpd nodes
        if len(trace.split('\n')) < self.np + 1 :
            subprocess.call(['condor_rm', '-all'])
            sys.exit('Error: not enough mpd nodes in the ring')

        # Run mpi job
        execdir = '/mnt/ganfs/' + gethostname(True) + '/tmp' + self.rand + '/'
        subprocess.call(['mpiexec', '-n', str(self.np), 
                         execdir + self.execfname.split('/')[-1]])

        # mpi job is finished
        subprocess.call( 'mpdallexit', stdout=FNULL, stderr=FNULL) # tear down mpd ring
        for host in self.hostlist:                                 # notify all workers
            hostserv = xmlrpclib.Server( "http://" + host[0] + ":" + host[4] )
            hostserv.terminate()

        self._rm_tmpdir( LOCAL_NFS_DIR )    # remove exec file from ganfs dir
        self._rm_tmpdir()                   # remove temp directory

    def _prepare_submission_files(self):

        # Prepare condor submission file
        self.submitFile.prepare_file( [ ['<q.np>', str(self.np-1)],
                        ['<ssh.pub.key>', self.tmpPath + AUTH_FNAME ],
                        ['<fullpath.client.script>', str(self.clientFile) ],
                        ['<client.script>', self.clientFile.out_fname() ] ] )

        # Prepare client side python script
        if self.debug:
            print 'serv ipop ip = ' + get_ipop_ip()
        self.clientFile.prepare_file(
                        [ [ '<serv.ip>', get_ipop_ip() ],
                        [ '<serv.port>', str(PORT) ],
                        [ '<mpd.port>', self.mpdPort ],
                        [ '<rand>', self.rand ] ] )

    def _read_hosts_info(self):
        with open( self.hostfname, 'r') as hostf:
            for line in hostf:
                self.hostlist.append( line.rstrip().split(":") ) 
        hostf.close()

        if self.debug:
              print '\nhost list:'
              for host in self.hostlist:
                  print host

    def _create_mpd_hosts(self):
        with open( self.tmpPath + 'mpd.hosts', 'w') as mpdhostf:
            for host in self.hostlist:
                # write hostname and number of cpus only
                mpdhostf.write( host[0] + ':' + host[1] + '\n' )
        mpdhostf.close()

    # Generate ssh key pairs for MPI ring
    def _gen_ssh_keys(self):

        argstr = str.split( "ssh-keygen -q -t rsa" )
        argstr.extend( ["-N", ''] )
        argstr.extend( ["-f", self.keyfname] )
        argstr.extend( ["-C", self.rand] )
    
        p = subprocess.call( argstr )
        if p != 0:
            sys.exit('Error: ssh-keygen return ' + str(p))

        # copy the public key file into 'authorized_keys' file for client's sshd
        shutil.copyfile( self.keyfname + '.pub', self.tmpPath + AUTH_FNAME )


if __name__ == "__main__":

    # parsing option/arguments
    parser = OptionParser(description='Submit MPI jobs via condor',
                usage='Usage: %prog [options] <source filename>' )
    parser.add_option('-n', dest = 'np', default = 1, type = 'int',
                help = "Number of processes to be run" )
    (options, args) = parser.parse_args()

    if len(args) != 1:
        parser.error("Incorrect number of arguments")

    # test the existance of exe file
    if not os.path.isfile( args[0] ):
        sys.exit('File ' + args[0] + '  not found')

    mpisubm = MPISubmission( options.np, args[0] )
    mpisubm.start()

