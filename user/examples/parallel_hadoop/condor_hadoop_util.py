#!/usr/bin/python

import socket, string, random, os, subprocess

def get_ipop_ip():
    iplist = socket.gethostbyname_ex( socket.gethostname())[2]
    return iplist[-1]

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

