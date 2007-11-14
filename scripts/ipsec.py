#!/usr/bin/python
from os import system
import sys, time, xmlrpclib

ip=sys.argv[1]
try:
  oldip=sys.argv[2]
except:
  oldip="poo"

if ip != oldip:
  rdir="/etc/racoon/certs"
  # Prepare ca key
  system("cp -f /mnt/fd/cacert.pem " + rdir + "/.")
  system("ln -sf " + rdir + "/cacert.pem " + rdir + "/`openssl x509 -noout -hash -in " + rdir + "/cacert.pem`.0")

  # Generate key
  system("openssl req -new -config /mnt/fd/user_config -keyout " + rdir + "/newkey.pem -out " + rdir + "/newreq.pem")
  system("openssl rsa -passin pass:mypass -in " + rdir + "/newkey.pem -out " + rdir + "/host-key.pem")
  system("rm -f ./newkey.pem")

  #read request
  f = open(rdir + "/newreq.pem", "rb")
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
  f = open(rdir + "/host-cert.pem", "wb+")
  f.write(cert)
  f.close()

#start racoon
system("/etc/ipsec-tools.conf")
system("/etc/init.d/racoon restart")
