#!/usr/bin/python

import sys, os, subprocess, shutil, time, xmlrpclib

from callback_serv import CallbackServ
from template_file import TemplateFile
from condor_hadoop_util import *
from optparse import OptionParser
from threading import Thread

DEBUG = 1
PORT = 32603                                   	# server listening port
SUBM_FNAME = 'submit_hadoop_vanilla'            # submission template file name
CONFTMP_FNAME = 'core-site.tmp.xml'            	# configure template file name
CONF_FNAME = 'core-site.xml'              	# configure file name
CLNT_FNAME = 'condor_hadoop_client.tmp.py'     	# client-side script template
AUTH_FNAME = 'authorized_keys'
NFS_PREFIX = '/mnt/ganfs/'
HADP_PATH = 'hadoop-0.21.0'                     # path of hadoop installation
JAVA_PATH = 'jdk1.6.0_23'                # path of jdk installation
OUTPUT_DIR = 'result'

FNULL = open('/dev/null', 'w')

class HadoopCluster():

    def __init__(self, np ):
        self.debug = DEBUG
        self.np = np
        self.nfsTmp = NFS_PREFIX + gethostname(True) 
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
        self.env = os.environ 
        self.env['PATH'] = self.nfsTmp + '/' + HADP_PATH + '/bin:' + self.env['PATH']
	self.env['HADOOP_HOME'] = self.nfsTmp + '/' + HADP_PATH 
	self.env['JAVA_HOME'] = self.nfsTmp + '/' + JAVA_PATH 

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

    def _stop_hadoop(self):
        subprocess.call( ['hadoop-daemon.sh', 'stop', 'namenode'], 
                         env=self.env, stdout=FNULL, stderr=FNULL)
        subprocess.call( ['hadoop-daemon.sh', 'stop', 'jobtracker'], 
                         env=self.env, stdout=FNULL, stderr=FNULL)

    def _start_hadoop(self):

        # make sure no other namenode/jobtracker are running
        self._stop_hadoop()

        # starting server's namenode
        self.env['HADOOP_CONF_DIR'] = self.nfsTmp + '/' + self.tmpPath 
        subprocess.call( ['echo', '"Y"', '>', 'hadoop', 'namenode', '-format'], 
                         env=self.env, stdout=FNULL, stderr=FNULL)
        subprocess.call( ['hadoop-daemon.sh','start','namenode'], 
                         env=self.env, stdout=FNULL, stderr=FNULL)

	''' 
        # determine mpd listening port from mpdtrace output
        process = subprocess.Popen(['mpdtrace', '-l'], stdout=subprocess.PIPE, env=self.env)
        process.wait()
        traceout = process.communicate()[0]
        port = extractPort(traceout)

        if not port.isdigit(): 
            sys.exit('Error starting mpd : ' + traceout )
        self.mpdPort = port
	'''

    def start(self):

        # Create conf file into local ganfs directory
        self._create_tmpdir( self.nfsTmp )
        confFile = TemplateFile( '' , CONFTMP_FNAME, self.nfsTmp + '/' + self.tmpPath, 
                                        CONF_FNAME )
        confFile.prepare_file([ ['<namenode.hostname>', gethostname()] ]);
        
        self._start_hadoop()                  # start local hadoop namenode & jobtracker
        self._prepare_submission_files()      # prepare client script and condor submit file
        self._gen_ssh_keys()                  # generate ssh key pairs

        # start a listening server
        self.servthread = Thread(target=CallbackServ(self.np, self.hostfname, PORT).serv)
        self.servthread.setDaemon(True)
        self.servthread.start()

        if self.debug:
            print "submit condor with file " + str(self.submitFile)

        p = subprocess.call(['condor_submit', str(self.submitFile) ] )
        if p != 0:
            sys.exit('Error: condor_submit return ' + str(p))

        # if the submission is successful, wait for the server 
        print 'Waiting for ' + str(self.np) + ' workers to response ....',
        sys.stdout.flush()
        self.servthread.join()
        print 'finished'
        self._read_hosts_info()        # read info from the collected hosts

	'''
        # Waiting for mpd ring to be ready
        limit = 10
        retry = 0
        while retry < limit :
            time.sleep(1.0)                # wait

            # testing mpd connection
            process = subprocess.Popen(['mpdtrace', '-l'], env=self.env, 
                                  stdout=subprocess.PIPE )
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
        execdir = self.nfsTmp + '/' + self.tmpPath
        subprocess.call(['mpiexec', '-n', str(self.np), 
                         execdir + self.execfname.split('/')[-1]], env=self.env)
	'''
        time.sleep(10.0)

        # mpi job is finished
        for host in self.hostlist:                                 # notify all workers
            hostserv = xmlrpclib.Server( "http://" + host[0] + ":" + host[4] )
            hostserv.terminate()

        self._stop_hadoop()                 # stop hadoop
        self._rm_tmpdir( self.nfsTmp )      # remove temp dir from ganfs dir
        self._rm_tmpdir()                   # remove temp directory

    def _prepare_submission_files(self):

        # Prepare condor submission file
        self.submitFile.prepare_file( [ ['<q.np>', str(self.np)],
                        ['<ssh.pub.key>', self.tmpPath + AUTH_FNAME ],
                        ['<fullpath.client.script>', str(self.clientFile) ],
                        ['<output.dir>', OUTPUT_DIR + '/' ],
                        ['<client.script>', self.clientFile.out_fname() ] ] )

        # Prepare client side python script
        if self.debug:
            print 'serv ipop ip = ' + get_ipop_ip()
        self.clientFile.prepare_file(
                        [ [ '<serv.ip>', get_ipop_ip() ],
                        [ '<serv.port>', str(PORT) ],
                        [ '<hadp.path>', self.nfsTmp + '/' + HADP_PATH ],
                        [ '<java.path>', self.nfsTmp + '/' + JAVA_PATH ],
                        [ '<conf.path>', self.nfsTmp + '/' + self.tmpPath ],
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
    '''
    def _create_mpd_hosts(self):
        with open( self.tmpPath + 'mpd.hosts', 'w') as mpdhostf:
            for host in self.hostlist:
                # write hostname and number of cpus only
                mpdhostf.write( host[0] + ':' + host[1] + '\n' )
        mpdhostf.close()
    '''

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
    parser = OptionParser(description='Start Hadoop pool via condor',
                usage='Usage: %prog [options]' )
    parser.add_option('-n', dest = 'np', default = 1, type = 'int',
                help = "Number of node to be started for Hadoop cluster" )
    (options, args) = parser.parse_args()

    if len(args) != 0:
        parser.error("Incorrect number of arguments")

    # Testing Hadoop & Java installation in GANFS
    local_nfs = NFS_PREFIX + gethostname(True)
    if not os.path.isfile( local_nfs + '/' + HADP_PATH + '/bin/hadoop' ):
        sys.exit('Error: No Hadoop installation in ' + local_nfs)
    if not os.path.isfile( local_nfs + '/' + JAVA_PATH + '/bin/java' ):
        sys.exit('Error: No Hadoop installation in ' + local_nfs)

    # Create condor output dir if not already existed
    if not os.path.isdir( OUTPUT_DIR ):
        try:
            os.makedirs( OUTPUT_DIR )
        except os.error as e:
            sys.exit('Error: cannot create directory - ' + e )

    hdp = HadoopCluster( options.np )
    hdp.start()
