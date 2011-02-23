#!/usr/bin/python
import xmlrpclib, sys, socket

ip = "127.0.0.1"
port = "10000"
socket.setdefaulttimeout(10)
server = xmlrpclib.Server("http://" + ip + ":" + port + "/xm.rem")
peer = sys.argv[1]
print server.localproxy("Ipop.GetState", peer)
