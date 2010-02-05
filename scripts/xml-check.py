#!/usr/bin/env python

from xml.sax.handler import ContentHandler
from xml.sax import make_parser
import sys

parser = make_parser()
parser.setContentHandler(ContentHandler())
try:
  parser.parse(sys.argv[1])
except:
  sys.exit(1)
