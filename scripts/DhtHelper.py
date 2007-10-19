#!/usr/bin/python
import sys, xmlrpclib, random

dhtip="127.0.0.1" #sys.argv[2]
dhtport=64221 #sys.argv[3]

proxyip="127.0.0.1"
proxyport=103182

def main():
  method = sys.argv[1]
  if method == "get":
    key = sys.argv[2]
    return get(key)
  elif method == "register":
    key = sys.argv[2]
    value = sys.argv[3]
    ttl = sys.argv[4]
    register(key, value, ttl)
  elif method == "unregister":
    key = sys.argv[2]
    value = sys.argv[3]
    ttl = sys.argv[4]
    unregister(key, value, ttl)

def get(key):
  dhtserver = xmlrpclib.Server("http://" + dhtip + ":" + dhtport + "/xd.rem")
  rv = ""
  if key == "server":
    ipop_ns = sys.argv[3]
    res = dhtserver.Get(ipop_ns + ":condor:server")
    if len(res) > 0:
      rv = res[random.randint(0, len(res))]["valueString"]
  elif key == "flock":
    ipop_ns = sys.argv[3]
    res = dhtserver.Get(ipop_ns + ":condor:server")
    if len(res) > 0:
      for entry in res:
        rv += entry["valueString"] + ", "
      rv = rv[:-2]
  print rv

def register(key, value, ttl):
  proxy = xmlrpclib.Server("http://" + proxyip + ":" + proxyport)
  proxy.register("put", key, value, ttl)


def unregister(key, value, ttl):
  proxy = xmlrpclib.Server("http://" + proxyip + ":" + proxyport)
  proxy.register("put", key, value, ttl)

if __name__ == "__main__":
  main()
