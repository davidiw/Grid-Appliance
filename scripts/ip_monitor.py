#!/usr/bin/python
""" This application gathers the local machines IP Addresses and their matching
labels.  Thereafter, it will notify, via callback, any IP address changes. """

import socket, struct, thread

"""4 byte alignment"""
def align(inc):
  diff = inc % 4
  return inc + ((4 - diff) % 4)

class ifaddr:
  """Parse an ifaddr packet"""
  LOCAL = 2
  LABEL = 3

  def __init__(self, packet):
    self.family, self.prefixlen, self.flags, self.scope, self.index = \
        struct.unpack("BBBBI", packet[:8])

class rtattr:
  """Parse a rtattr packet"""
  GRP_IPV4_IFADDR = 0x10

  NEWADDR = 20
  DELADDR = 21
  GETADDR = 22

  def __init__(self, packet):
    self.len, self.type = struct.unpack("HH", packet[:4])
    if self.type == ifaddr.LOCAL:
      addr = struct.unpack("BBBB", packet[4:self.len])
      self.payload = "%s.%s.%s.%s" % (addr[0], addr[1], addr[2], addr[3])
    elif self.type == ifaddr.LABEL:
      self.payload = packet[4:self.len].strip("\0")
    else:
      self.payload = packet[4:self.len]

class netlink:
  """Parse a netlink packet"""
  REQUEST = 1
  ROOT = 0x100
  MATCH = 0x200
  DONE = 3

  def __init__(self, packet):
    self.msglen, self.msgtype, self.flags, self.seq, self.pid = \
        struct.unpack("IHHII", packet[:16])
    self.ifa = None
    try:
      self.ifa = ifaddr(packet[16:24])
    except:
      return

    self.rtas = {}
    pos = 24
    while pos < self.msglen:
      try:
        rta = rtattr(packet[pos:])
      except:
        break
      pos += align(rta.len)
      self.rtas[rta.type] = rta.payload

class ip_monitor:
  def __init__(self, callback = None):
    if callback == None:
      callback = self.print_cb
    self._callback = callback

  def print_cb(self, label, addr):
    print label + " => " + addr

  def request_addrs(self, sock):
    sock.send(struct.pack("IHHIIBBBBI", 24, rtattr.GETADDR, \
      netlink.REQUEST | netlink.ROOT | netlink.MATCH, 0, sock.getsockname()[0], \
      socket.AF_INET, 0, 0, 0, 0))

  def start_thread(self):
    thread.start_new_thread(self.run, ())

  def run(self):
    sock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, socket.NETLINK_ROUTE)
    sock.bind((0, rtattr.GRP_IPV4_IFADDR))
    self.request_addrs(sock)

    while True:
      data = sock.recv(4096)
      pos = 0
      while pos < len(data):
        nl = netlink(data[pos:])
        if nl.msgtype == netlink.DONE:
          break
        pos += align(nl.msglen)
        if nl.msgtype != rtattr.NEWADDR:
          continue
        self._callback(nl.rtas[ifaddr.LABEL], nl.rtas[ifaddr.LOCAL])

if __name__ == "__main__":
  ip_monitor().run()
