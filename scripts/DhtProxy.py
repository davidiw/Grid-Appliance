#!/usr/bin/python
import SimpleXMLRPCServer, sys, xmlrpclib, threading
from datetime import timedelta, datetime

# input parameters
port=103182 #sys.argv[1]
dhtip=64221 #sys.argv[2]
dhtport="127.0.0.1" #sys.argv[3]
# contains a tuple of next update, key, value, ttl
values = []
# dictionary of the keys for fast access
values_p = {}
# interrupts the output handler to let him know if a new key has shortest ttl
data_change = threading.Event()
# connect to the DhtProxy
dhtserver = xmlrpclib.Server("http://" + dhtip + ":" + dhtport + "/xd.rem")
# Lock to maintain the values consistency
values_lock = threading.Lock()

def main():
  output_thread = threading.Thread(target=output_handler())
  output_thread.start()
  input_handler()

# Enables the listener
def input_handler():
  server = SimpleXMLRPCServer.SimpleXMLRPCServer(("localhost", int(port)))
  server.register_introspection_functions()
  server.register_instance(DhtProxy())
  server.serve_forever()

#we wait for an event from the other thread or for a timeout to end first
#which ever happens first and then we push the new data
class output_handler:
  def __call__(self):
    data_change.wait()

    while True:
      if len(values) == 0:
        data_change.wait()
        continue
      values_lock.acquire(1)
      lcount = 0
      for lvalues in values:
        if lvalues[0][0] > datetime.now():
          break
        for index in range(len(lvalues)):
          link = lvalues[index]
          if link[0] > datetime.now():
            break
          else:
            link = lvalues[0]
            dhtserver.Put(link[1], link[2], link[3])
            lvalues[index] = (timedelta(seconds=link[3] / 2) + datetime.now(), link[1], link[2], link[3])
      sort_values()
      values_lock.release()

# Converts a time delta to seconds for ttl
def timedelta_to_seconds(td):
  seconds = td.days * 24 * 60 * 60
  seconds += td.seconds
  return seconds

# appends on a value to the the values or replaces it if it already exists
def append_on_values(new_link):
  key = new_link[1]
  found = False
  if key not in values_p:
    values_p[key] = []
    values.append(values_p[key])
  else:
    for index in range(len(values_p)):
      if new_link[2] == values_p[key][index][2]:
        values_p[key][index] = new_link
        found = True
        break
  if not found:
    values_p[key].append(new_link)

# sorts the values first by individual key ttls, then by the shortest overall
def sort_values():
  val = values[0][0][0]
  for lvalues in values:
    lvalues.sort(cmp=lambda x, y: cmp(x[0], y[0]))
  values.sort(cmp=lambda x, y: cmp(x[0][0], y[0][0]))
  return val == values[0][0][0]

class DhtProxy:
  #attempt action once, if success return true and add it to the dictionary
  def register(self, action, key, value, ttl):
    if action == "put":
      res = dhtserver.Put(key, value, ttl)
    elif action == "create":
      res = dhtserver.Create(key, value, ttl)
    else:
      res = False

    if res:
      values_lock.acquire(1)
      append_on_values((datetime.now() + timedelta(seconds = ttl / 2) , key, value, ttl))
      nchange = sort_values()
      values_lock.release()
      if not nchange:
        data_change.set()
    return res

  #remove from the registered values
  def unregister(self, key, value):
    pos = 0
    found = False
    values_lock.acquire(1)
    if key in values_p:
      for index in range(len(values_p[key])):
        if values_p[key][index][3] == key:
          del values_p[key][index]
          found = True
          break
    nchange = sort_values()
    values_lock.release()
    if nchange:
      data_change.set()
    return found

  def dump(sel):
    return values

if __name__ == "__main__":
  main()
