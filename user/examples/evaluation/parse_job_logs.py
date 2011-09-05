#!/usr/bin/python

from datetime import datetime, timedelta
import re, os, sys

if len(sys.argv) != 3:
  print "Usage: %s path outfile" % (sys.argv[0], )

path = sys.argv[1]
outfile = sys.argv[2]
start = "Job submitted from host"
end = "Job terminated"
time_re = re.compile("[0-9]+\/[0-9]+ [0-9:]+")
time_format = "%m/%d %H:%M:%S"
times = []

for filename in os.listdir(path):
  f = open("%s%s%s" % (path, os.sep, filename))
  start_time = ""
  end_time = ""
  for line in f:
    if line.find(start) != -1:
      start_time = time_re.search(line).group(0)
    elif line.find(end) != -1:
      end_time = time_re.search(line).group(0)

  f.close()

  if not end_time or not start_time:
    continue
  start_time = datetime.strptime(start_time, time_format)
  end_time = datetime.strptime(end_time, time_format)
  times.append(end_time - start_time)

times.sort()
f = open(outfile, "w+")
for time in times:
  f.write("%s%s" % (time.total_seconds(), "\n"))
f.close()
