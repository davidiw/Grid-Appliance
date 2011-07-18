#!/usr/bin/env python

# example helloworld.py

import gtk, gobject, pygtk, utils

class xmonitor:
  LOCAL_NIC = "The appliance can be access via: "
  IPOP = "Networking is currently "
  CONDOR = "Grid middleware is currently "

  WAITING = 0
  CONFIGURING = 1
  RUNNING = 2

  def destroy(self, widget, data=None):
    gtk.main_quit()

  def add_label(self, box, label):
    align = gtk.Alignment()
    align.add(label)
    box.pack_start(align, expand = False, fill = False, padding = 0)

    label.show()
    align.show()

  def __init__(self):
    window = gtk.Window(gtk.WINDOW_TOPLEVEL)
    window.set_geometry_hints(None, min_width = 400)
    window.set_title("Grid Appliance XMonitor")
    window.connect("destroy", self.destroy)
    window.set_border_width(2)

    w_vbox = gtk.VBox(homogeneous = False, spacing = 0)

    frame = gtk.Frame("Welcome to the Grid Appliance")
    w_vbox.pack_start(frame, expand = False, fill = False, padding = 0)
    vbox = gtk.VBox(homogeneous = False, spacing = 0)
    frame.add(vbox)

    username = utils.run("whoami")
    user_name = gtk.Label("Your user name is %s" % (username, ))
    self.add_label(vbox, user_name)
    password = gtk.Label("The default password is password")
    self.add_label(vbox, password)

    vbox.show()
    frame.show()

    frame = gtk.Frame("System Information")
    w_vbox.pack_start(frame, expand = False, fill = False, padding = 0)
    vbox = gtk.VBox(homogeneous = False, spacing = 0)
    frame.add(vbox)

    self.local_nic = gtk.Label()
    self.local_nic_state = ""
    self.add_label(vbox, self.local_nic)
    self.ipop_info = gtk.Label()
    self.monitor_state = -1
    self.add_label(vbox, self.ipop_info)
    self.condor_info = gtk.Label()
    self.add_label(vbox, self.condor_info)

    self.update()
    vbox.show()
    frame.show()

    w_vbox.show()
    window.add(w_vbox)
    window.show()

    self.timer = gobject.timeout_add(1000, self.update)

  def update(self):
    local_nic_state = utils.utils_sh("get_ip eth1")
    if local_nic_state != self.local_nic_state:
      self.local_nic_state = local_nic_state
      self.local_nic.set_text("%s%s" % (xmonitor.LOCAL_NIC, local_nic_state))

    monitor_state = utils.check_monitor()
    if monitor_state != self.monitor_state:
      self.monitor_state = monitor_state
      if monitor_state == False:
        self.ipop_info.set_text("%s%s" % (xmonitor.IPOP, "waiting"))
        self.condor_info.set_text("%s%s" % (xmonitor.CONDOR, "waiting"))
      elif monitor_state == 0:
        self.ipop_info.set_text("%s%s" % (xmonitor.IPOP, "configuring"))
        self.condor_info.set_text("%s%s" % (xmonitor.CONDOR, "waiting"))
      elif monitor_state == 1:
        self.ipop_info.set_text("%s%s" % (xmonitor.IPOP, "running"))
        self.condor_info.set_text("%s%s" % (xmonitor.CONDOR, "configuring"))
      elif monitor_state == 2:
        self.ipop_info.set_text("%s%s" % (xmonitor.IPOP, "running"))
        self.condor_info.set_text("%s%s" % (xmonitor.CONDOR, "running"))

    return True

  def main(self):
    gtk.main()

if __name__ == "__main__":
  xmon = xmonitor()
  xmon.main()
