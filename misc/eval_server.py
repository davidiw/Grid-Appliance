#!/usr/bin/python

from SimpleXMLRPCServer import SimpleXMLRPCServer, SimpleXMLRPCRequestHandler
from datetime import datetime, timedelta
import sys, base64

current_request = None

class request_handler(SimpleXMLRPCRequestHandler):
  def __init__(self, request, client_address, server):
    globals()["current_request"] = client_address
    SimpleXMLRPCRequestHandler.__init__(self, request, client_address, server)

class eval_server:
  def __init__(self, count, floppy_data):
    self.count = count
    self.floppy_data = base64.b64encode(floppy_data)
    self.uids = []
    self.started = False
    self.delay = 120
    self.ips = []
    self.called = 0

  def serve(self):
    self.server = SimpleXMLRPCServer(("0.0.0.0", 55555), requestHandler=request_handler, logRequests=False)
    self.server.register_function(self.register)
    self.server.register_function(self.start)
    self.server.register_function(self.time_until_start)
    self.server.register_function(self.total)
    self.server.register_function(self.get_info)
    self.server.serve_forever()

  def register(self, uid):
    if uid in self.uids:
      return self.floppy_data

    self.uids.append(uid)
    self.ips.append(current_request)

    if len(self.uids) == self.count:
      print "All nodes are registered."
    else:
      print "Count at " + str(len(self.uids))

    return self.floppy_data

  def start(self):
    if self.started:
      return True

    self.started = True
    self.start_time = datetime.utcnow() + timedelta(seconds = self.delay)
    return True

  def time_until_start(self):
    if self.started:
      self.called += 1
      print "Nodes started: " + str(self.called)
      td = self.start_time - datetime.utcnow()
      seconds = td.days * 86400 + td.seconds
      return max(seconds, 0)
    else:
      return -1

  def total(self):
    return len(self.uids)

  def get_info(self):
    return self.ips

if __name__ == "__main__":
  if len(sys.argv) != 3:
    print "Usage: %s count path_to_floppy" % (sys.argv[0], )
    sys.exit(-1)

  try:
    count = int(sys.argv[1])
  except:
    print "Invalid count: %s" % (sys.argv[1])

  floppy_file = open(sys.argv[2])
  try:
    floppy_data = floppy_file.read()
  except:
    print "Invalid file %s" % (sys.argv[2], )
  finally:
    floppy_file.close()

  server = eval_server(count, floppy_data)
  server.serve()
