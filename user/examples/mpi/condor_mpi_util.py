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

# Create .mpd.conf file with a given secret word
def createMpdConf( secret, dest=os.getcwd() ):

    # prepare mpd config file
    with open( dest + '/.mpd.conf', 'w' ) as outf:
        outf.write( 'MPD_SECRETWORD=' + secret )
    outf.close()
    os.chmod( dest+'/.mpd.conf', 0600 )

# Get host name
def gethostname():
    return socket.gethostname().split('.')[0]

# Extract port number from mpdtrace output
def extractPort( trace ):
    return trace.split()[0].split('_')[-1]
