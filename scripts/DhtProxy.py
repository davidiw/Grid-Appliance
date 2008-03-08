#!/usr/bin/python
import SimpleXMLRPCServer, sys, xmlrpclib, threading
from datetime import timedelta, datetime

# input parameters
port=103182 #sys.argv[1]
dhtport="64221" #sys.argv[2]
dhtip="127.0.0.1" #sys.argv[3]
# an array containing values_p in earliest deadline first
values = []
# dictionary ordered by keys containing arrays of tuples containing next update, key, value, ttl
values_p = {}
# interrupts the output handler to let him know if a new key has shortest ttl
data_change = threading.Event()
# connect to the DhtProxy
dhtserver = xmlrpclib.Server("http://" + dhtip + ":" + dhtport + "/xd.rem")
# Lock to maintain the values consistency
values_lock = threading.Lock()

def main():
  output_thread = threading.Thread(target=output_handler())
  output_thread.setDaemon(True)
  output_thread.start()
  input_handler()

# Enables the listener
def input_handler():
  server = SimpleXMLRPCServer.SimpleXMLRPCServer(("localhost", port))
  server.register_introspection_functions()
  server.register_instance(DhtProxy())
  server.serve_forever()

#we wait for an event from the other thread or for a timeout to end first
#which ever happens first and then we push the new data
class output_handler:
  def __call__(self):
    data_change.wait()
    data_change.clear()

    while True:
      if len(values) == 0:
        data_change.wait()
        data_change.clear()
        continue
      t = timedelta_to_seconds(values[0][0][0] - datetime.now()) + 1
      if(values[0][0][0] < datetime.now()):
        t = 0
      data_change.wait(t)
      data_change.clear()
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
            try:
              res = dhtserver.Put(link[1], link[2], link[3])
            except:
              res = false
            if res:
              retry = datetime.now() + timedelta(seconds=link[3] / 2)
            else:
              retry = 30
            lvalues[index] = (retry, link[1], link[2], link[3])
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
    for index in range(len(values_p[key])):
      if new_link[2] == values_p[key][index][2]:
        values_p[key][index] = new_link
        found = True
        break
  if not found:
    values_p[key].append(new_link)

# sorts the values first by individual key ttls, then by the shortest overall
def sort_values():
  if len(values) == 0:
    return False
  val = values[0][0][0]
  for lvalues in values:
    # comparison can't be 0 or it will overwrite
    lvalues.sort(cmp=lambda x, y: cmp(x[0], y[0]))
    # comparison can't be 0 or it will overwrite
  values.sort(cmp=lambda x, y: cmp(x[0][0], y[0][0]))
  return val == values[0][0][0]

class DhtProxy:
  #Register if action succeeds or i register_if_fail is true
  def rif_register(self, action, key, value, ttl, register_if_fail):
    key = str(key)
    value = str(value)
    ttl = int(ttl)
    register_if_fail = bool(register_if_fail)

    res = False
    try:
      if action == "put":
        res = dhtserver.Put(key, value, ttl)
      elif action == "create":
        res = dhtserver.Create(key, value, ttl)
      else:
        return False
    except:
      pass

    if res or register_if_fail:
      values_lock.acquire(1)
      if res:
        retry = datetime.now() + timedelta(seconds = ttl / 2)
      else:
        retry = datetime.now() + timedelta(seconds = 30)
      append_on_values((retry , key, value, ttl))
      nchange = sort_values()
      values_lock.release()
      if not nchange or len(values) == 1:
        data_change.set()
    return res

  #attempt action once, if success return true and add it to the dictionary
  def register(self, action, key, value, ttl):
    return self.rif_register(action, key, value, ttl, False)

  #remove from the registered values
  def unregister(self, key, value):
    pos = 0
    found = False
    values_lock.acquire(1)
    if key in values_p:
      for index in range(len(values_p[key])):
        if values_p[key][index][2] == value:
          if len(values_p[key]) == 1:
            for idx in range(len(values)):
              if values[idx][0][1] == key: 
                del values[idx]
                del values_p[key]
                break
          else:
            del values_p[key][index]
          found = True
          break
    nchange = sort_values()
    values_lock.release()
    if not nchange:
      data_change.set()
    return found

  def dump(self):
    dump_res = []
    for key in values_p.iterkeys():
      dump_res.append([])
      i = len(dump_res) - 1
      for tup in values_p[key]:
        dump_res[i].append(((tup[0] - datetime.now()).seconds, tup[1], tup[2], tup[3]))
    return dump_res

if __name__ == "__main__":
  main()
