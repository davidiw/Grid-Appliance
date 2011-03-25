#!/usr/bin/python

from xml.sax.handler import ContentHandler
from xml.sax import make_parser
import socket, subprocess, sys, xmlrpclib

def _rpc_init(ip = "127.0.0.1", port = 10000, service = "xm.rem"):
  socket.setdefaulttimeout(10)
  return xmlrpclib.Server("http://%s:%s/%s" % (ip, port, service))

def check_connections():
  try:
    neighbors = _rpc_init().localproxy("sys:link.GetNeighbors")
  except:
    return False

  return "right" in neighbors and "left" in neighbors

def check_condor_running():
  pid = utils_sh("get_pid condor_master")
  return pid != False

def check_condor_manager_ip():
  ga = parse_config("/etc/grid_appliance.config")
  f = open("%s/var/condor_manager" % (ga["DIR"], ), "r")
  manager_ip = f.read().strip()
  f.close()

  return manager_ip == run("condor_config_val CONDOR_HOST")

def check_condor_manager():
  return run("condor_status -negotiator") != False

def check_ip():
  server = _rpc_init()
  try:
    info = _rpc_init().localproxy("Information.Info")
  except:
    return False

  dhtip = "dhcp:" + info["IpopNamespace"] + ":" + info["VirtualIPs"][0]

  try:
    vals = server.localproxy("DhtClient.Get", xmlrpclib.Binary(dhtip))
  except:
    return False

  return len(vals) > 0

def check_monitor():
  ga = parse_config("/etc/grid_appliance.config")
  try:
    return _rpc_init(port = ga["MONITOR_PORT"], service = "").current_state()
  except:
    return False

def check_self():
  try:
    return "self" in _rpc_init().localproxy("sys:link.GetNeighbors")
  except:
    return False

def information():
  try:
    return _rpc_init().localproxy("Information.Info")
  except:
    return False

def parse_config(filename):
  f = open(filename, "r")
  data = f.readlines()
  f.close()

  vals = {}
  for line in data:
    val = line.partition('=')
    key, value = val[0].strip(), val[2].strip().strip("\'\"")
    if key == "" or value == "":
      continue
    vals[key] = value
  return vals

def run(command):
  null = open("/dev/null", "w")

  try:
    p = subprocess.Popen(command.split(' '), stdin=null, stdout=subprocess.PIPE, stderr=null)
  except:
    null.close()
    return False

  p.wait()
  null.close()
  if p.returncode == 0:
    return p.stdout.read().strip()
  return False

def utils_sh(command):
  ga = parse_config("/etc/grid_appliance.config")
  return run("%s/scripts/utils.sh %s" % (ga["DIR"], command))

def xml_check(filename):
  parser = make_parser()
  parser.setContentHandler(ContentHandler())
  try:
    parser.parse(filename)
  except:
    return False
  return True

class log_write:
  def __init__(self, path):
    self._path = path

  def write(self, msg):
    f = open(self._path, "a+")
    f.write(msg)
    f.close()

if __name__ == "__main__":
  if len(sys.argv) < 2:
    sys.exit("Missing argument")
  method = sys.argv[1]
  args = []
  if len(sys.argv) > 2:
    args = sys.argv[2:]

  try:
    res = globals()[method](*args)
  except:
    res = False

  print res
  if not res:
    sys.exit(-1)
