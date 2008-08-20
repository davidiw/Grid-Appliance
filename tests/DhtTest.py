#!/usr/bin/python
import xmlrpclib, time, random, socket
from datetime import datetime

dhtip="127.0.0.1"
dhtport="64221"

proxyip="127.0.0.1"
proxyport="103182"

keys=500
values=3
ttl_min=120
ttl_max=600

socket.setdefaulttimeout(10)
dht = xmlrpclib.Server("http://" + dhtip + ":" + dhtport + "/xd.rem")
proxy = xmlrpclib.Server("http://" + proxyip + ":" + proxyport)

def main():
  start = datetime.now()

  for i in range(keys):
    print "Inserting key:  " + str(i)
    for j in range(values):
      put(str(i), str(j), random.randint(ttl_min, ttl_max))

  while True:
    count = 0
    for i in range(keys):
#      print "Retrieving key:  " + str(i)
      res = get(str(i))
      ex_res = range(values)
      for index in range(len(res)):
        ex_res[int(res[index]["valueString"])] = 0
      lcount = 0
      for index in ex_res:
        if ex_res[index] != 0:
          lcount += 1
#      print "Results for " + str(i) + " = " + str(lcount)
      count += lcount
    print "Results for pool at " + str(datetime.now() - start) + " time since start = " + str(count)
    print "Sleeping for 5 minutes"
    time.sleep(60)

def get(key):
  return dht.Get(key)

def put(key, value, ttl):
  proxy.rif_register("put", key, value, ttl, True)

def remove(key, value):
  proxy.unregister(key, value)

if __name__ == "__main__":
  main()
