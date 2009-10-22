#!/usr/bin/python
import sys, xmlrpclib, random, time, socket

def main():
  method = sys.argv[1]
  if method == "get":
    key = sys.argv[2]
    return get(key)
  elif method == "register":
    key = sys.argv[2]
    value = sys.argv[3]
    ttl = int(sys.argv[4])
    register(key, value, ttl)
  elif method == "unregister":
    key = sys.argv[2]
    value = sys.argv[3]
    unregister(key, value)
  elif method == "dump":
    key = None
    if len(sys.argv) == 3:
      key = sys.argv[2]
    dump(key)

def get(key):
  rpc = xmlrpclib.Server("http://127.0.0.1:10000/xm.rem")
  rv = ""
  if key == "server":
    ipop_ns = sys.argv[3]
    res = rpc.localproxy("DhtClient.Get", xmlrpclib.Binary(ipop_ns + ":condor:server"))
    if len(res) > 0:
      rv = res[random.randint(0, len(res) - 1)]["value"].data
  elif key == "flock":
    ipop_ns = sys.argv[3]
    res = rpc.localproxy("DhtClient.Get", xmlrpclib.Binary(ipop_ns + ":condor:server"))
    if len(res) > 0:
      for entry in res:
        rv += entry["value"].data + ", "
      rv = rv[:-2]
  else:
    try:
      rv = rpc.localproxy("DhtClient.Get", xmlrpclib.Binary(key))
    except:
      rv = ""
  print rv

def register(key, value, ttl):
  rpc = xmlrpclib.Server("http://127.0.0.1:10000/xm.rem")
  rpc.localproxy("RpcDhtProxy.Register", xmlrpclib.Binary(key), xmlrpclib.Binary(value), ttl)

def unregister(key, value):
  rpc = xmlrpclib.Server("http://127.0.0.1:10000/xm.rem")
  rpc.localproxy("RpcDhtProxy.Unregister", xmlrpclib.Binary(key), xmlrpclib.Binary(value))

def dump(key = None):
  rpc = xmlrpclib.Server("http://127.0.0.1:10000/xm.rem")
  res = rpc.localproxy("RpcDhtProxy.ListEntries")
  skip = False
  if(key == None):
    skip = True
  for entry in res:
    if(not skip and entry["Key"].data != key):
      continue
    print entry["Key"].data + ", " + entry["Value"].data 

if __name__ == "__main__":
  for i in range(3):
    try:
      main()
      break
    except socket.error, detail:
      time.sleep(2)
      if i == 2:
        print detail
