#!/usr/bin/python

from datetime import datetime, timedelta
import re, os, sys

if len(sys.argv) != 4:
  print "Usage: %s init_time infile outfile" % (sys.argv[0], )
  sys.exit(-1)

begin_time = sys.argv[1]
path = sys.argv[2]
outfile = sys.argv[3]
startd_insert = "StartdAd     : Inserting"
time_re = re.compile("[0-9]+\/[0-9]+\/[0-9]+ [0-9:]+")
time_format = "%m/%d/%y %H:%M:%S"
delay = timedelta(seconds = 120)
begin_time = datetime.strptime(begin_time, time_format)

times = []

f = open(path)
for line in f:
  ctime = time_re.search(line).group(0)
  ctime = datetime.strptime(ctime, time_format)
  if begin_time > ctime:
    continue
  if line.find(startd_insert) != -1:
    times.append(ctime - begin_time - delay)

f.close()

for idx in range(len(times)):
  time = times[idx]
  if time.total_seconds() > 60:
    break
  times.append(time)
  times.append(time + timedelta(seconds = 1))
times.sort()

f = open(outfile, "w+")
for time in times:
  f.write("%s%s" % (time.total_seconds(), "\n"))
f.close()
