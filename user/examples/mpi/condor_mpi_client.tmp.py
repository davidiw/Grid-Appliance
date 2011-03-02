#!/usr/bin/python

import os, xmlrpclib, time, subprocess, multiprocessing

from SimpleXMLRPCServer import SimpleXMLRPCServer
from condor_mpi_util import *
from getpass import getuser
from threading import Thread

SERV_IP =  '<serv.ip>' 
SERV_PORT = '<serv.port>'
MPD_PORT = '<mpd.port>'
MPD_PATH = '<mpd.path>'
RAND = '<rand>'
SEED_XMLPORT = 45555

class WaitingServ:

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

    user = getuser()
    hostname = gethostname()
    xmlport = str( SEED_XMLPORT + condor_slot )
    cpus = str(multiprocessing.cpu_count())
    path = os.getcwd()

    # construct a dict for all values and make xmlrpc call
    data = { 'hostname' : hostname, 'cpus' : cpus, 'usrname' : user,
             'xmlport' : xmlport, 'path' : path }
    serv.write_file( data )

    createMpdConf( RAND )
    env = os.environ
    env['MPD_CONF_FILE'] = path + '/.mpd.conf'
    subprocess.Popen([MPD_PATH + '/mpd', '-h', SERV_IP, '-p', MPD_PORT], env=env)

    # start the server, waiting for terminating signal    
    servthread = start_server( int(xmlport) )
    servthread.join()

