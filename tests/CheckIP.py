#!/usr/bin/python
import xmlrpclib, sys, socket

ip = "127.0.0.1"
port = "10000"
socket.setdefaulttimeout(10)
server = xmlrpclib.Server("http://" + ip + ":" + port + "/xm.rem")

info = server.localproxy("Information.Info")
dhtip = "dhcp:" + info["IpopNamespace"] + ":" + info["VirtualIPs"][0]
print len(server.localproxy("DhtClient.Get", xmlrpclib.Binary(dhtip))) > 0
