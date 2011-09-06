#!/usr/bin/python

import xmlrpclib

ip = "www.grid-appliance.org"
port = "55555"

server = xmlrpclib.ServerProxy("http://%s:%s" % (ip, port))
ips = {}
for pair in server.get_info():
  ip = pair[0]
  ip_parts =  pair[0].split('.')
  ip_net = "%s.%s.%s.0" % (ip_parts[0], ip_parts[1], ip_parts[2])
  if ip_net not in ips:
    ips[ip_net] = 0
  ips[ip_net] += 1
print len(server.get_info())
print server.total()
