#!/usr/bin/python
import xmlrpclib, sys, socket

ip = "127.0.0.1"
port = "10000"
socket.setdefaulttimeout(10)
server = xmlrpclib.Server("http://" + ip + ":" + port + "/xm.rem")
res = True
try:
  res &= "self" in server.localproxy("sys:link.GetNeighbors")
except:
  res = False
print res
sys.exit(res)
