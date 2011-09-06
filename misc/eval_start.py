#!/usr/bin/python

import xmlrpclib

ip = "www.grid-appliance.org"
port = "55555"

server = xmlrpclib.ServerProxy("http://%s:%s" % (ip, port))
print server.total()
print server.start()
