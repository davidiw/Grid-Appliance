#!/usr/bin/python
from matplotlib import pyplot, rc
import sys

rc('font', **{'size' : 16})
markers = ['^', 's', 'o', 'v', '<', '>', '+', 'x']
markers.reverse()
fig = pyplot.figure()

for filename in sys.argv[1:]:
  x = []
  f = open(filename)
  for line in f:
    x.append(float(line))
  f.close()
  y = map(lambda i: (i * 1.0) / len(x), range(len(x)))

  count = len(x)
  idx = 0

  while idx < count:
    if idx == 0:
      pass
    elif x[idx] == x[idx - 1]:
      x.pop(idx - 1)
      y.pop(idx - 1)
      count -= 1
    idx += 1

  pyplot.step(x, y, '-' + markers.pop(), where = 'post', label = filename)
pyplot.ylabel("CDF")
pyplot.xlabel("Time in seconds")
pyplot.legend(loc = "lower right")
pyplot.subplots_adjust(bottom = .08, right = .96, top = .98, left = .1)
pyplot.savefig('out.eps')
