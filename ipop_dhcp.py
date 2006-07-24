#! /usr/bin/env python

# ****************************************************************************************************
# (c) Advanced Computing and Information Systems lab
#     University of Florida
#     P.O. Box 116200
#     339 Larsen Hall
#     Gainesville
#     FL 32611-6200
#     USA
# ***************************************************************************************************
# This script acts as the client and performs the following functions:
#    1) Gets a string from server containing IP address, Hostname and location from where to fetch 
#       the tarball containing configuration files.
#    2) Parses the string and retrieves the IP Address, Hostname and the URL
#    3) Fetches the tar ball from the URL
#    4) Passes the IP address and the Hostname to the "setup" script which takes care of the rest
#
# Usage python grid_new.py
# ***************************************************************************************************
# Author: Abhishek Agrawal
# E-Mail: aagrawal@acis.ufl.edu
# ***************************************************************************************************

import sys, os, commands, tempfile, xmlrpclib, urllib

server = xmlrpclib.ServerProxy("http://128.227.56.247:8601")
result = server.getResult()
list = result.split(";")
ip = list[0]
fetch = list[1]
hostname = list[2]

# Fetching the tar ball from the URL. Names it as config.tar.gz and puts in the current directory
urllib.urlretrieve(fetch,"/root/client/config.tar.gz")

# Write /root/client/var/grid_client_lastcall
f = open('/root/client/var/grid_client_lastcall', 'w')
f.write(ip)
f.write(":")
f.write(hostname)