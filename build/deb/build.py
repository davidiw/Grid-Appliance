#!/usr/bin/env python
"""
This script builds deb packages using a config file using ini format:
[build]
version = some_number
base_path = path/to/files
package = name_of_package
[debian]
debian_file = true
control = true
prerm = true
...
[files]
local_file = file/in/package
etc/file = /opt/special/etc/file
[links]
/opt/special/etc/file = /etc/file
[directories]
/opt/some/other/dir = true

Where:
- build contains meta information
- debian is the special debian files in the package, value doesn't matter
- files map a base_path + "/" + file to package + "/" + file/in/package
- links creates a link from the key to the value
- directories create empty directories, value doesn't matter
"""

import ConfigParser, os, os.path, shutil, sys, errno

# Critical meta options
options = ["version", "base_path", "package"]

def mkdir(path):
  try:
    os.makedirs(path)
  except OSError as exc:
    if exc.errno != errno.EEXIST:
      raise


def exists(path):
  if not os.path.exists(path) or not os.path.isfile(path):
    print "Missing " + path + " file"
    sys.exit(1)

def main():
  exists("config")

  config = ConfigParser.RawConfigParser()
  config.optionxform = str
  config.read("config")

  if not config.has_section("build"):
    print "Missing build section in config"

  for option in options:
    if not config.has_option("build", option): 
      print "Missing " + option + " in build section"

  package = config.get("build", "package")
  version = config.get("build", "version")
  base_path = config.get("build", "base_path")

  # Prep directory
  if os.path.exists(package):
    shutil.rmtree(package)
  mkdir(package)

  # Copy files
  if config.has_section("files"):
    for src in config.options("files"):
      dst = package + "/" + config.get("files", src)
      src = base_path + "/" + src
      dirname = os.path.dirname(dst)

      if os.path.exists(dirname):
        if not os.path.isdir(dirname):
          print "Should be a directory: " + dirname
          sys.exit(1)
      else:
        mkdir(dirname)

      shutil.copy2(src, dst)

  # Make links
  if config.has_section("links"):
    for src in config.options("links"):
      dst = package + "/" + config.get("links", src)
      dirname = os.path.dirname(dst)

      if os.path.exists(dirname):
        if not os.path.isdir(dirname):
          print "Should be a directory: " + dirname
          sys.exit(1)
      else:
        mkdir(dirname)

      os.symlink(src, dst)

  # Make directories
  if config.has_section("directories"):
    for directory in config.options("directories"):
      mkdir(package + "/" + directory)

  # Copy debian files and the deb file
  if config.has_section("debian"):
    path = package + "/" + "DEBIAN"
    mkdir(path)

    for dfile in config.options("debian"):
      shutil.copy2(dfile, path + "/" + dfile)

      if dfile == "control":
        f = open(path + "/" + dfile, "a")
        f.write("Version: " + version + "\n")
        f.close()

    os.system("dpkg-deb -b " + package)
    shutil.rmtree(package)
    shutil.move(package + ".deb", package + "_" + version + ".deb")

if __name__ == '__main__':
  main()
