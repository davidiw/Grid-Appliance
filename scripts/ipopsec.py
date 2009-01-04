#!/usr/bin/python
import sys, time, xmlrpclib, os, base64, pickle
dir = "/usr/local/ipop"

node_address=sys.argv[1]
try:
  old_na=sys.argv[2]
except:
  old_na="poo"

if old_na == node_address:
  sys.exit()

# Get the CA Cert from the Floppy
os.system("cp /mnt/fd/cacert " + dir + "/tools/certificates/ca.cert")
# Create cert / key
os.chdir(dir + "/tools")
cmd = "mono certhelper.exe makecert "
cmd += "inkey=" + dir + "/tools/private_key "
cmd += "outcert=" + dir + "/var/tosign "

f = open("/mnt/fd/ipopsec_userinfo", "rb")
userinfo = f.read()
f.close()

for line in userinfo.split('\n'):
  params = line.split('=')
  if(len(params) < 2):
    continue
  cmd += params[0] + "=\"" + params[1] + "\" "
cmd += "node_address=" + node_address

os.system(cmd)

#get secret key
f = open("/mnt/fd/ipopsec_secret", "rb")
secret = f.read().strip(' \n\t\r')
f.close()

#read request
f = open(dir + "/var/tosign", "rb")
cert = base64.urlsafe_b64encode(f.read())
f.close()

# send request
f = open("/mnt/fd/ipopsec_server")
server_url = f.read().strip(' \n\t\r')
f.close()

while True:
  try:
    server = xmlrpclib.Server(server_url)
    res = server.CertificateRequest(cert, secret)
    break
  except:
    time.sleep(300)

#receive cert
while True:
  try:
    cert = server.CertificateInquiry(res, secret)
    if cert != "wait":
      cert = base64.urlsafe_b64decode(cert)
      break
  except:
    pass
  time.sleep(300)

#write cert
f = open(dir + "/tools/certificates/lc.cert", "wb+")
f.write(cert)
f.close()

while True:
  try:
    ipop = xmlrpclib.Server("http://127.0.0.1:10000/xm.rem")
    ipop.localproxy("Security.AddCertificate", "lc.cert")
    ipop.localproxy("Security.AddCertificate", "ca.cert")
    break
  except:
    pass
  time.sleep(5)

