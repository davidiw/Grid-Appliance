#!/usr/bin/python
import xmlrpclib, sys, base64

ip = "127.0.0.1"
port = "10000"
server = xmlrpclib.Server("http://" + ip + ":" + port + "/xm.rem")
res = server.localproxy("dht.Dump")
for l1 in res:
  for l2 in l1:
    for l3 in l2:
      for l4 in l3.iterkeys():
        if l4 == "key" or l4 == "value":
          l3[l4] = base64.b64decode(l3[l4].data)
      print l3
print server.localproxy("dht.Count")
