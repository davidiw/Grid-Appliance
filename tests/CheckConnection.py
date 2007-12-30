#!/usr/bin/python
import xmlrpclib, sys

ip = "127.0.0.1"
port = "10000"
server = xmlrpclib.Server("http://" + ip + ":" + port + "/xm.rem")
res = False
try:
  res |= "right" in server.localproxy("sys:link.GetNeighbors")[0]
  res |= "left" in server.localproxy("sys:link.GetNeighbors")[0]
except:
  pass
sys.exit(res)
