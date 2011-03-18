#!/usr/bin/python
# Monitor the state of our features (Brunet, IPOP, and Condor)

from SimpleXMLRPCServer import SimpleXMLRPCServer
import ip_monitor, time, thread, Queue, os, sys, utils

ipop = utils.parse_config("/etc/ipop.vpn.config")
ga = utils.parse_config("/etc/grid_appliance.config")

class monitor:
  """Queue commands"""
  IP = 0

  """States"""
  WAIT_ON_IPOP = 0
  CONFIGURING_CONDOR = 1
  RUNNING = 2
  RESTARTING_IPOP = 3

  """Timeouts"""
  MIN_TIMEOUT = 30
  MAX_TIMEOUT = 300

  def __init__(self):
    self.queue = Queue.Queue()

    self.ipmon = ip_monitor.ip_monitor(self.ip_callback)
    self.ipmon.start_thread()

    self.ips = {}
    self.timeout = self.MAX_TIMEOUT

    self.server = SimpleXMLRPCServer(("localhost", int(ga["MONITOR_PORT"])), logRequests = False)
    self.server.register_function(self.list_ips)
    self.server.register_function(self.current_state)
    self.server.register_function(self.print_next_timeout)
    thread.start_new_thread(self.server.serve_forever, ())

    self.state = 0

  def list_ips(self):
    return self.ips
  
  def current_state(self):
    return self.state

  def print_next_timeout(self):
    self.print_timeout = True
    return True

  def handle_ip(self, label, addr):
    if label in self.ips and addr == self.ips[label]:
      return
    self.ips[label] = addr

    if label == ipop["DEVICE"]:
      utils.utils_sh("set_hostname")
      # Now that IPOP is running, let's get Condor running
      # If Condor is running, we should reconfig, since we have a new IP
      if not self.check_condor():
        self.timeout = monitor.MIN_TIMEOUT
    elif label == "eth1":
      os.system("/etc/init.d/grid_appliance.sh ssh")
      os.system("/etc/init.d/grid_appliance.sh samba")

  def check_condor(self, just_check = False):
    reconfig = True

    if not utils.check_condor_running():
      print "Condor not running..."
      reconfig = False
    elif not utils.check_condor_manager_ip():
      print "Condor manager IP mismatch..."
    elif not utils.check_condor_manager():
      print "Unable to contact Condor manager..."
    else:
      if self.state != monitor.RUNNING:
        print "All systems nominal..."
        self.state = monitor.RUNNING
      return True

    if not just_check:
      print "Restarting Condor..."
      self.restart_condor(reconfig = reconfig)

    if not just_check:
      return self.check_condor(just_check = True)
    return False

  def handle_timeout(self):
    self.timeout = monitor.MIN_TIMEOUT

    if not utils.check_self():
      self.restart_ipop()
      return
    elif ipop["DEVICE"] not in self.ips:
      return
    elif not utils.check_connections():
      return
    elif not self.check_condor():
      return

    self.state = monitor.RUNNING
    self.timeout = monitor.MAX_TIMEOUT
    os.system("%s/bin/dump_dht_proxy.py %s/etc/dht_proxy" % (ipop["DIR"], ipop["DIR"]))

  def ip_callback(self, label, addr):
    self.queue.put((monitor.IP, label, addr))

  def restart_ipop(self):
    print "Restarting IPOP..."
    self.state = monitor.RESTARTING_IPOP
    # In some rare cases, these files will be improperly extracted, who knows why
    for filename in ("ipop.config", "node.config", "bootstrap.config", "dhcp.config"):
      if utils.xml_check(ipop["DIR"] + "/etc/" + filename):
        continue
      print "Found a broken config..."
      os.system("groupvpn_prepare.sh %s/var/groupvpn.zip" % (ga["DIR"], ))
      break
    os.system("/etc/init.d/groupvpn.sh stop")

    # if we don't have a working hostname, things break, if we don't have an IP
    # address that resolves properly, then other things begin to break
    os.system("hostname localhost")
    os.system("resolvconf -u")
    os.system("/etc/init.d/groupvpn.sh start")

  def restart_condor(self, reconfig = False):
    self.state = monitor.CONFIGURING_CONDOR
    param = "restart"
    if reconfig:
      param = "reconfig"
    os.system("%s/scripts/condor.sh %s" % (ga["DIR"], param))

  def run(self):
    timeout = self.timeout
    while True:
      start_time = int(time.time())
      try:
        msg = self.queue.get(block = True, timeout = self.timeout)
      except:
        if self.print_timeout:
          print "Timeout occurred at %s" % (time.ctime(), )
          self.print_timeout = False
        self.handle_timeout()
        timeout = self.timeout
        continue

      print "Handling an incoming message: %s, at %s" % (msg, time.ctime())
      if msg[0] == monitor.IP:
        self.handle_ip(msg[1], msg[2])

      ctime = int(time.time())
      # We don't want to wait an entire timeout to check timeout handler...
      timeout = timeout - (ctime - start_time)
      self.queue.task_done()

if __name__ == "__main__":
  if len(sys.argv) > 1 and sys.argv[1] == "daemon":
    sys.stdout = utils.log_write("/var/log/monitor.log")
    sys.stderr = sys.stdout
    monitor().run()
  else:
    os.system("%s/bin/daemon.py \"%s/scripts/monitor.py daemon\"" % (ipop["DIR"], ga["DIR"]))
