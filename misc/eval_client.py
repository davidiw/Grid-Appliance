#!/usr/bin/python

import base64, os, random, sys, time, xmlrpclib

ip = "www.grid-appliance.org"
port = "55555"
timeout = 30

uid = random.random()

server = xmlrpclib.ServerProxy("http://%s:%s" % (ip, port))
while True:
  try:
    floppy_data = base64.b64decode(server.register(uid))
    break
  except:
    time.sleep(timeout)

try:
  time_until_start = server.time_until_start()
except:
  time_until_start = -1


while time_until_start == -1:
  time.sleep(timeout)
  try:
    time_until_start = server.time_until_start()
  except:
    time_until_start = -1

time.sleep(time_until_start)

f = open("/tmp/floppy.zip", "w+")
f.write(floppy_data)
f.close()
os.system("unzip -d /opt/grid_appliance/etc /tmp/floppy.zip")
os.system("/etc/init.d/grid_appliance.sh start")
