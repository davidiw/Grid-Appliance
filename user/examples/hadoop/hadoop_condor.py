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
CONF_TMP_FNAME = 'core-site.tmp.xml'            # configure template file name
HENV_TMP_FNAME = 'hadoop-env.tmp.sh'            # hadoop-env.sh template file name
HDFS_TMP_FNAME = 'hdfs-site.tmp.xml'
CONF_FNAME = 'core-site.xml'              	# configure file name
HENV_FNAME = 'hadoop-env.sh'                    # hadoop env setup script file name
HDFS_FNAME = 'hdfs-site.xml'
CLNT_FNAME = 'condor_hadoop_client.tmp.py'     	# client-side script template
NFS_PREFIX = '/mnt/ganfs/'
HADP_PATH = 'hadoop'                     # path of hadoop installation
JAVA_PATH = 'jdk'                        # path of jdk installation
OUTPUT_DIR = 'result'

FNULL = open('/dev/null', 'w')

class HadoopCluster:

    def __init__(self, np ):
        self.debug = DEBUG
        self.np = np
        self.nfsTmp = NFS_PREFIX + gethostname(True) 
        self.servthread = None
        self.rand = 'hadoopAAA'
        self.tmpPath = self._create_tmpdir()
        self.submitFile = TemplateFile( '' , SUBM_FNAME, self.tmpPath, 
                                        SUBM_FNAME + '_' + self.rand )
        self.clientFile = TemplateFile( '' , CLNT_FNAME, self.tmpPath, 
                                        CLNT_FNAME + '_' + self.rand )
        self.hostfname = self.tmpPath + 'hosts_' + self.rand
        self.hostlist = []             # store a list of [username, ip, port]
        self.env = os.environ 
        self.env['PATH'] = self.nfsTmp + '/' + HADP_PATH + '/bin:' + self.env['PATH']
	self.env['HADOOP_HEAPSIZE'] = str(128)
        self.env['HADOOP_CONF_DIR'] = os.getcwd() + '/' + self.tmpPath

    # remove tmp dir and all its content
    def _rm_tmpdir(self, dst='.'):
        tpath = dst + '/tmp' + self.rand
        if os.path.isdir( tpath ):
            try:
                if os.access( tpath, os.F_OK) == True:
                    shutil.rmtree( tpath )
            except os.error as e:
                sys.exit('Error: cannot remove temp directory - ' + e )

    def _create_tmpdir(self, dst='.'):
        tmpdir = dst + '/tmp' + self.rand
        if not os.path.isdir( tmpdir ):
            try:
                os.makedirs( tmpdir )
            except os.error as e:
                sys.exit('Error: cannot create temp directory - ' + e )
        return 'tmp' + self.rand + '/'

    def _stop_hadoop(self):
        subprocess.call( ['stop-all.sh'], 
                         env=self.env, stdout=FNULL, stderr=FNULL)
        #subprocess.call( ['hadoop-daemon.sh', 'stop', 'jobtracker'], 
        #                 env=self.env, stdout=FNULL, stderr=FNULL)

    def _start_hadoop(self):

        # starting server's namenode
        p1 = subprocess.Popen( ['echo', 'Y'], stdout=subprocess.PIPE, stderr=FNULL)
        subprocess.call( ['hdfs', 'namenode', '-format'], env=self.env, 
                         stdin=p1.stdout, stdout=FNULL, stderr=FNULL )
        p1.stdout.close()
        print 'Starting a namenode ... ',
        sys.stdout.flush()
        #subprocess.call( ['hadoop-daemon.sh', 'start','namenode'], 
        subprocess.Popen( ['hdfs','namenode'], 
                         env=self.env, stdout=FNULL, stderr=FNULL)

        # use -report to wait for namenode to finish starting up
        subprocess.call(['hdfs', 'dfsadmin' ,'-report'], 
                          env=self.env, stdout=FNULL, stderr=FNULL )
        print 'done'

        # Start local datanode
        print 'Starting a local datanode\n'
        #subprocess.call( ['hadoop-daemon.sh', 'start','datanode'], 
        subprocess.Popen( ['hdfs','datanode'], 
                         env=self.env, stdout=FNULL, stderr=FNULL)
    def start(self):

        # Create conf file into local temp directory
        confFile = TemplateFile( '' , CONF_TMP_FNAME, self.tmpPath, CONF_FNAME )
        confFile.prepare_file([ ['<namenode.hostname>', gethostname()] ])

        hdfsFile = TemplateFile( '', HDFS_TMP_FNAME, self.tmpPath, HDFS_FNAME )
        hdfsFile.prepare_file([ ['<name.dir>', self.tmpPath + 'name' ],
                                ['<data.dir>', self.tmpPath + 'data' ] ] )

        # Prepare and copy hadoop-env.sh into local temp directory
        envFile = TemplateFile('', HENV_TMP_FNAME, self.tmpPath, HENV_FNAME )
        envFile.prepare_file([ ['<java.home>', self.nfsTmp + '/' + JAVA_PATH],
                               ['<hadoop.home>', self.nfsTmp + '/' + HADP_PATH],
                               ['<path>', self.nfsTmp + '/' + HADP_PATH + '/bin:$PATH']]
                               , True )

        self._start_hadoop()                # start local hadoop namenode & jobtracker
        self._prepare_submission_files()    # prepare client script and condor submit file

        # start a listening server
        self.servthread = Thread(target=CallbackServ(self.np-1, self.hostfname, PORT).serv)
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

        # Waiting for hadoop cluster to be ready
        print '\nWaiting for ' + str(self.np) + ' datanodes to be ready .... ',
        sys.stdout.flush()
        limit = 180
        retry = 0
        while retry < limit :
            time.sleep(1.0)

            # testing hadoop cluster
            process = subprocess.Popen(['hdfs', 'dfsadmin' ,'-report'], 
                                  env=self.env, stdout=subprocess.PIPE, stderr=FNULL )
            process.wait()
            trace = process.communicate()[0]
            retry += 1

            # extract datanodes count
            start = trace.find("Datanodes available:")
            end = trace.find("(", start )
            count = trace[start:end].split()[-1]

            if count.isdigit() and (int(count) == self.np ):
                print 'success'
                break

        # Check whether mpdtrace return enough mpd nodes
        if retry >=  limit :
            print 'fail'
            self.stop()
            sys.exit('Timeout: not enough datanodes in the cluster')

    def stop(self):
        self._read_hosts_info()              # read info from tmp dir
        if len(self.hostlist) == 0 :
            sys.exit('Error: no existing hadoop cluster info' )

        for host in self.hostlist:                                 # notify all workers
            hostserv = xmlrpclib.Server( "http://" + host[0] + ":" + host[3] )
            hostserv.terminate()

        self._stop_hadoop()                 # stop hadoop
        self._rm_tmpdir()                   # remove temp directory

    def _prepare_submission_files(self):
        # Prepare condor submission file
        self.submitFile.prepare_file( [ ['<q.np>', str(self.np-1)],
                        ['<fullpath.client.script>', str(self.clientFile) ],
                        ['<output.dir>', OUTPUT_DIR + '/' ],
                        ['<core.config.file>', self.tmpPath + CONF_FNAME ],
                        ['<hdfs.config.tmp.file>', HDFS_TMP_FNAME ],
                        ['<env.config.file>', self.tmpPath + HENV_FNAME ],
                        ['<client.script>', self.clientFile.out_fname() ] ] )

        # Prepare client side python script
        if self.debug:
            print 'serv ipop ip = ' + get_ipop_ip()
        self.clientFile.prepare_file(
                        [ [ '<serv.ip>', get_ipop_ip() ],
                        [ '<serv.port>', str(PORT) ],
                        [ '<hadp.path>', self.nfsTmp + '/' + HADP_PATH ],
                        [ '<java.path>', self.nfsTmp + '/' + JAVA_PATH ],
                        [ '<hdfs.config.file>', HDFS_FNAME ],
                        [ '<hdfs.config.tmp.file>', HDFS_TMP_FNAME ],
                        [ '<rand>', self.rand ] ] )

    def _read_hosts_info(self):
        self.hostlist = []
        with open( self.hostfname, 'r') as hostf:
            for line in hostf:
                self.hostlist.append( line.rstrip().split(":") ) 
        hostf.close()

        if self.debug:
              print '\nhost list:'
              for host in self.hostlist:
                  print host

if __name__ == "__main__":

    # parsing option/arguments
    parser = OptionParser(description='Start Hadoop pool via condor',
                usage='Usage: %prog [options] {start|stop}' )
    parser.add_option('-n', dest = 'np', default = 1, type = 'int',
                help = "Number of node to be started for Hadoop cluster" )
    (options, args) = parser.parse_args()

    if len(args) != 1:
        parser.error("Incorrect number of arguments")

    if ((args[0] != 'start') and (args[0] != 'stop')) :
        parser.error("Unknown command")

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

    if args[0] == 'start':
        hdp.start()
    elif args[0] == 'stop':
        hdp.stop()
