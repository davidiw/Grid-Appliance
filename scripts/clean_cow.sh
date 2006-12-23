# Usage:
#   ./clean_cow.sh dir
#   where dir is the directory you want to clean out.
#   For example, in the case of a double mounted unionfs, a user would run
#   `./clean_cow.sh /.unionfs`
#   `./clean_cow.sh /.unionfs/.unionfs`
#!/bin/bash
rm -rf $1/usr/local/ipop/{config,griduser,readme,scripts,setup,tools,etc}
rm -rf $1/*vmware*
rm -rf $1/*/*vmware*
rm -rf $1/*/*/*vmware*
rm -rf $1/*/*/*/*vmware*
rm -rf $1/*/*/*/*/*vmware*
rm -rf $1/opt/condor