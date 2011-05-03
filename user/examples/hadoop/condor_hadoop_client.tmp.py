#!/usr/bin/python

import os, xmlrpclib, time, subprocess, multiprocessing

from SimpleXMLRPCServer import SimpleXMLRPCServer
from condor_hadoop_util import *
from getpass import getuser
from threading import Thread
from template_file import TemplateFile

SERV_IP =  '<serv.ip>' 
SERV_PORT = '<serv.port>'
HADP_PATH = '<hadp.path>'
JAVA_PATH = '<java.path>'
RAND = '<rand>'
HDFS_FNAME = '<hdfs.config.file>'
HDFS_TMP_FNAME = '<hdfs.config.tmp.file>'
SEED_XMLPORT = 45555
HADOOP_LOGDIR = 'hadoop_log'

class WaitingServ():

    def __init__(self, port):
        self.port = port
        self.running = True

    def terminate(self):
        self.running = False
        return 0

    def serv(self):
        server = SimpleXMLRPCServer(("0.0.0.0", self.port), logRequests = False)
        server.register_function(self.terminate)
        while self.running:
            server.handle_request()

def start_server( port ):
    srvthrd = Thread( target=WaitingServ( port ).serv )
    srvthrd.setDaemon(True)
    srvthrd.start()
    return srvthrd

if __name__ == "__main__":

    condor_slot =  int(os.environ['_CONDOR_SLOT'])
    serv = xmlrpclib.Server( "http://" + SERV_IP + ":" + SERV_PORT )

    local_user = getuser()
    local_hostname = gethostname()
    local_xmlport = str( SEED_XMLPORT + condor_slot )
    local_cpus = str(multiprocessing.cpu_count())
    local_path = os.getcwd()

    # construct a dict for all values and make xmlrpc call
    data = { 'hostname' : local_hostname, 'cpus' : local_cpus, 'usrname' : local_user,
             'xmlport' : local_xmlport, 'path' : local_path }
    serv.write_file( data )

    # prepare log and conf dir
    name_dir = 'tmp' + RAND + '/name'
    data_dir = 'tmp' + RAND + '/data'
    os.makedirs( HADOOP_LOGDIR )
    os.makedirs( name_dir )
    os.makedirs( data_dir )

    hdfsFile = TemplateFile( '', HDFS_TMP_FNAME, '', HDFS_FNAME )
    hdfsFile.prepare_file([ ['<name.dir>', local_path + '/' + name_dir ],
                            ['<data.dir>', local_path + '/' + data_dir ] ] )

    # Setup datanode/tasktracker in the background
    local_env = os.environ
    local_env['HADOOP_CONF_DIR'] = local_path
    local_env['HADOOP_HOME'] = HADP_PATH
    local_env['HADOOP_LOG_DIR'] = local_path + '/' + HADOOP_LOGDIR
    local_env['HADOOP_PID_DIR'] = local_path + '/' + HADOOP_LOGDIR
    local_env['HADOOP_HEAPSIZE'] = str(128)
    local_env['JAVA_HOME'] = JAVA_PATH
    subprocess.call( [HADP_PATH + '/bin/hadoop-daemon.sh', 'start', 'datanode'], env=local_env)

    # start the server, waiting for terminating signal    
    servthread = start_server( int(local_xmlport) )
    servthread.join()
    os.remove( HDFS_FNAME )   # remove file to prevent condor from creating it
