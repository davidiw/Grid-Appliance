#!/usr/bin/python

import socket, string, random, os, subprocess, fcntl, struct

def get_ipop_ip():
   s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
   ifname = struct.pack('256s', 'tapipop')
   return socket.inet_ntoa(fcntl.ioctl(s.fileno(), 0x8915, ifname)[20:24])

# Generate a random alphanumeric word
def genRandom( minlength=8, maxlength=8 ):
    length = random.randint(minlength, maxlength)
    letters = string.ascii_letters + string.digits
    return ''.join([random.choice(letters) for _ in range(length)])

# Get host name
def gethostname( short = False ):
    name = socket.gethostname()
    if not short:
        return name

    return name.split('.')[0]  # short hostname, return the first part

