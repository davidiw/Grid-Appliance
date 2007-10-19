#!/usr/bin/python
from os import system
import sys, time, xmlrpclib

ip=sys.argv[1]
oldip=sys.argv[2]
system("cp /mnt/fd/cacert.pem /etc/racoon/.")

if ip != oldip:
  rdir="/etc/racoon/certs"

  # Generate key
  system("openssl req -new -config /mnt/fd/openssl_user.conf -out " + rdir + "/newreq.pem")
  system("openssl rsa -passin pass:mypass -in " + dir + "/newkey.pem -out " + rdir + "/host-key.pem")

  #read request
  f = open(dir + "/newreq.pem", "rb")
  key = f.read()
  f.close()

  # send request
  f = open("/mnt/fd/ipsec_server")
  server_url = f.read()
  f.close()

  while True:
    try:
      server = xmlrpclib.Server(server_url)
      break
    except:
      time.sleep(300)

  res = server.IPsecRequest(key, ip)

  #receive cert
  while True:
    try:
      cert = server.IPsecCertificate(res)
      if cert != "wait":
        break
    except:
      pass
    time.sleep(300)

  #write cert
  f = open(rdir + "/etc/racoon/host-cert.pem", "wb+")
  f.write(cert)
  f.close()

#start racoon
system("/etc/ipsec-tools.conf")
system("/etc/init.d/racoon restart")