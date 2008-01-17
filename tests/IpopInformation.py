#!/usr/bin/python
import xmlrpclib, sys

ip = "127.0.0.1"
port = "10000"
server = xmlrpclib.Server("http://" + ip + ":" + port + "/xm.rem")
print server.localproxy("ipop.Information")[0]
