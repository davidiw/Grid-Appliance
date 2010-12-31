#!/usr/bin/python

import os, socket, xmlrpclib, time, subprocess, multiprocessing

from SimpleXMLRPCServer import SimpleXMLRPCServer
from condor_mpi_util import *
from getpass import getuser
from threading import Thread

SERV_IP =  '<serv.ip>' 
SERV_PORT = '<serv.port>'
MPD_PORT = '<mpd.port>'
RAND = '<rand>'
SEED_SSHPORT = 55555
SEED_XMLPORT = 45555

class WaitingServ():

    def __init__(self, port):
        self.port = port
        self.running = True

    def terminate(self):
        self.running = False
        return 0

    def serv(self):
        server = SimpleXMLRPCServer(("0.0.0.0", self.port))
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
    local_hostname = socket.gethostname()
    local_sshport = str( SEED_SSHPORT + condor_slot )
    local_xmlport = str( SEED_XMLPORT + condor_slot )
    local_cpus = str(multiprocessing.cpu_count())
    local_path = os.getcwd()

    # construct a dict for all values and make xmlrpc call
    data = { 'hostname' : local_hostname, 'cpus' : local_cpus, 'usrname' : local_user,
             'sshport' : local_sshport, 'xmlport' : local_xmlport,
             'path' : local_path }
    serv.write_file( data )

    subprocess.call( ['mpi_sshd_setup.sh'] )
    createMpdConf( RAND )
    subprocess.Popen(['mpd', '-h', SERV_IP, '-p', MPD_PORT], env={'MPD_CONF_FILE': local_path +'/.mpd.conf'})

    # start the server, waiting for terminating signal    
    servthread = start_server( int(local_xmlport) )
    servthread.join()

