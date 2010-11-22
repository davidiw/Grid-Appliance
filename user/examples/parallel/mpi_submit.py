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

class MPISubmission():

    def __init__(self, np, srcfname ):
        self.debug = DEBUG
        self.np = np
        self.srcfname = srcfname
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
    def _rm_tmpdir(self):
        try:
            if os.access(self.tmpPath[:-1], os.F_OK) == True:
                shutil.rmtree( self.tmpPath[:-1] )
        except os.error as e:
            sys.exit('Error removing temp directory : ' + e )

    def _create_tmpdir(self):
        try:
            os.mkdir( 'tmp' + self.rand )
        except os.error as e:
            sys.exit('Error creating temp directory : ' + e )
        return 'tmp' + self.rand + '/'

    def start(self):
        self._gen_ssh_keys()                  # generate ssh key pairs
        self._prepare_submission_files()      # prepare client script and condor submit file

        # start a listening server
        self.servthread = Thread( target=CallbackServ(self.np, self.hostfname, PORT).serv )
        self.servthread.setDaemon(True)
        self.servthread.start()
    
        if self.debug:
            print "submit condor with file " + str(self.submitFile)

        p = subprocess.call(['condor_submit', str(self.submitFile) ] )
        if p != 0:
            sys.exit('Error: condor_submit return ' + str(p))

        # if the submission is successful, wait for the server 
        print 'Waiting for ' + str(self.np) + ' workers to response .... '
        sys.stdout.flush()
        self.servthread.join()
        print 'finished'
        self._read_hosts_info()        # read info from the colltected hosts

        # start mpd ring here
        print 'simulate the running of  mpi jobs ..... '
        time.sleep(20)

        # notify all workers after the mpi job is finished
        for host in self.hostlist:
            hostserv = xmlrpclib.Server( "http://" + host[0] + ":" + host[4] )
            hostserv.terminate()

        self._rm_tmpdir()             # remove temp directory

    def _prepare_submission_files(self):

        # Prepare condor submission file
        self.submitFile.prepare_file( [ ['<q.np>', str(self.np)],
                        ['<ssh.pub.key>', self.tmpPath + AUTH_FNAME ],
                        ['<fullpath.client.script>', str(self.clientFile) ],
                        ['<client.script>', self.clientFile.out_fname() ] ] )

        # Prepare client side python script
        if self.debug:
            print 'serv ipop ip = ' + get_ipop_ip()
        self.clientFile.prepare_file(
                        [ [ '<serv.ip>', get_ipop_ip() ],
                        [ '<serv.port>', str(PORT) ],
                        [ '<rand>', self.rand ] ] )

    def _read_hosts_info(self):
        with open( self.hostfname, 'r') as hostf:
            for line in hostf:
                self.hostlist.append( line.rstrip().split(":") ) 
        hostf.close()

        if self.debug:
              print 'host list:'
              for host in self.hostlist:
                  print host

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

    mpisubm = MPISubmission( options.np, args[0] )
    mpisubm.start()

