#!/usr/bin/env python2.6
#
#   (C) 2001 by Argonne National Laboratory.
#       See COPYRIGHT in top-level directory.
#

"""
usage:  mpdboot --totalnum=<n_to_start> [--file=<hostsfile>]  [--help] \ 
                [--rsh=<rshcmd>] [--user=<user>] [--mpd=<mpdcmd>]      \ 
                [--loccons] [--remcons] [--shell] [--verbose] [-1]     \
                [--ncpus=<ncpus>] [--ifhn=<ifhn>] [--chkup] [--chkuponly] \
                [--maxbranch=<maxbranch>]
 or, in short form, 
        mpdboot -n n_to_start [-f <hostsfile>] [-h] [-r <rshcmd>] [-u <user>] \ 
                [-m <mpdcmd>]  -s -v [-1] [-c]

--totalnum specifies the total number of mpds to start; at least
  one mpd will be started locally, and others on the machines specified
  by the file argument; by default, only one mpd per host will be
  started even if the hostname occurs multiple times in the hosts file
-1 means remove the restriction of starting only one mpd per machine; 
  in this case, at most the first mpd on a host will have a console
--file specifies the file of machines to start the rest of the mpds on;
  it defaults to mpd.hosts
--mpd specifies the full path name of mpd on the remote hosts if it is
  not in your path
--rsh specifies the name of the command used to start remote mpds; it
  defaults to ssh; an alternative is rsh
--shell says that the Bourne shell is your default for rsh' 
--verbose shows the ssh attempts as they occur; it does not provide
  confirmation that the sshs were successful
--loccons says you do not want a console available on local mpd(s)
--remcons says you do not want consoles available on remote mpd(s)
--ncpus indicates how many cpus you want to show for the local machine;
  others are listed in the hosts file
--ifhn indicates the interface hostname to use for the local mpd; others
  may be specified in the hostsfile
--chkup requests that mpdboot try to verify that the hosts in the host file
  are up before attempting start mpds on any of them; it just checks the number
  of hosts specified by -n
--chkuponly requests that mpdboot try to verify that the hosts in the host file
  are up; it then terminates; it just checks the number of hosts specified by -n
--maxbranch indicates the maximum number of mpds to enter the ring under another;
  the default is 4
"""

# workaround to suppress deprecated module warnings in python2.6
# see https://trac.mcs.anl.gov/projects/mpich2/ticket/362 for tracking
import warnings
warnings.filterwarnings('ignore', '.*the popen2 module is deprecated.*', DeprecationWarning)

from time import ctime
__author__ = "Ralph Butler and Rusty Lusk"
__date__ = ctime()
__version__ = "$Revision: 1.49 $"
__credits__ = ""

import re

from os       import environ, path, kill, access, X_OK
from sys      import argv, exit, stdout
from popen2   import Popen4, Popen3, popen2
from socket   import gethostname, gethostbyname_ex
from select   import select, error
from signal   import SIGKILL
from commands import getoutput, getstatusoutput
from mpdlib   import mpd_set_my_id, mpd_get_my_username, mpd_same_ips, \
                     mpd_get_ranks_in_binary_tree, mpd_print, MPDSock

global myHost, fullDirName, rshCmd, user, mpdCmd, debug, verbose

def mpdboot():
    global myHost, fullDirName, rshCmd, user, mpdCmd, debug, verbose
    myHost = gethostname()
    mpd_set_my_id('mpdboot_%s' % (myHost) )
    fullDirName  = path.abspath(path.split(argv[0])[0])
    rshCmd = 'ssh'
    user = mpd_get_my_username()
    mpdCmd = path.join(fullDirName,'mpd')
    hostsFilename = 'mpd.hosts'
    totalnumToStart = 1    # may get chgd below
    debug = 0
    verbose = 0
    localConArg  = ''
    remoteConArg = ''
    oneMPDPerHost = 1
    myNcpus = 1
    myIfhn = ''
    chkupIndicator = 0  # 1 -> chk and start ; 2 -> just chk
    maxUnderOneRoot = 4
    try:
        shell = path.split(environ['SHELL'])[-1]
    except:
        shell = 'csh'

    argidx = 1    # skip arg 0
    while argidx < len(argv):
        if   argv[argidx] == '-h' or argv[argidx] == '--help':
            usage()
        elif argv[argidx] == '-r':    # or --rsh=
            rshCmd = argv[argidx+1]
            argidx += 2
        elif argv[argidx].startswith('--rsh'):
            splitArg = argv[argidx].split('=')
            try:
                rshCmd = splitArg[1]
            except:
                print 'mpdboot: invalid argument:', argv[argidx]
                usage()
            argidx += 1
        elif argv[argidx] == '-u':    # or --user=
            user = argv[argidx+1]
            argidx += 2
        elif argv[argidx].startswith('--user'):
            splitArg = argv[argidx].split('=')
            try:
                user = splitArg[1]
            except:
                print 'mpdboot: invalid argument:', argv[argidx]
                usage()
            argidx += 1
        elif argv[argidx] == '-m':    # or --mpd=
            mpdCmd = argv[argidx+1]
            argidx += 2
        elif argv[argidx].startswith('--mpd'):
            splitArg = argv[argidx].split('=')
            try:
                mpdCmd = splitArg[1]
            except:
                print 'mpdboot: invalid argument:', argv[argidx]
                usage()
            argidx += 1
        elif argv[argidx] == '-f':    # or --file=
            hostsFilename = argv[argidx+1]
            argidx += 2
        elif argv[argidx].startswith('--file'):
            splitArg = argv[argidx].split('=')
            try:
                hostsFilename = splitArg[1]
            except:
                print 'mpdboot: invalid argument:', argv[argidx]
                usage()
            argidx += 1
        elif argv[argidx].startswith('--ncpus'):
            splitArg = argv[argidx].split('=')
            try:
                myNcpus = int(splitArg[1])
            except:
                print 'mpdboot: invalid argument:', argv[argidx]
                usage()
            argidx += 1
        elif argv[argidx].startswith('--ifhn'):
            splitArg = argv[argidx].split('=')
            myIfhn = splitArg[1]
            myHost = splitArg[1]
            argidx += 1
        elif argv[argidx] == '-n':    # or --totalnum=
            totalnumToStart = int(argv[argidx+1])
            argidx += 2
        elif argv[argidx].startswith('--totalnum'):
            splitArg = argv[argidx].split('=')
            try:
                totalnumToStart = int(splitArg[1])
            except:
                print 'mpdboot: invalid argument:', argv[argidx]
                usage()
            argidx += 1
        elif argv[argidx].startswith('--maxbranch'):
            splitArg = argv[argidx].split('=')
            try:
                maxUnderOneRoot = int(splitArg[1])
            except:
                print 'mpdboot: invalid argument:', argv[argidx]
                usage()
            argidx += 1
        elif argv[argidx] == '-d' or argv[argidx] == '--debug':
            debug = 1
            argidx += 1
        elif argv[argidx] == '-s' or argv[argidx] == '--shell':
            shell = 'bourne'
            argidx += 1
        elif argv[argidx] == '-v' or argv[argidx] == '--verbose':
            verbose = 1
            argidx += 1
        elif argv[argidx] == '-c' or argv[argidx] == '--chkup':
            chkupIndicator = 1
            argidx += 1
        elif argv[argidx] == '--chkuponly':
            chkupIndicator = 2
            argidx += 1
        elif argv[argidx] == '-1':
            oneMPDPerHost = 0
            argidx += 1
        elif argv[argidx] == '--loccons':
            localConArg  = '-n'
            argidx += 1
        elif argv[argidx] == '--remcons':
            remoteConArg = '-n'
            argidx += 1
        else:
            print 'mpdboot: unrecognized argument:', argv[argidx]
            usage()
    if debug:
        print 'debug: starting'

    lines = []
    if totalnumToStart > 1:
        try:
            f = open(hostsFilename,'r')
            for line in f:
                lines.append(line)
        except:
            print 'unable to open (or read) hostsfile %s' % (hostsFilename)
            exit(-1)
#    hostsAndInfo = [ {'host' : myHost, 'ncpus' : myNcpus, 'ifhn' : myIfhn} ]
    hostsAndInfo = [ {'host' : myHost, 'ncpus' : myNcpus, 'ifhn' : myIfhn} ]
    hostsKeywords = [ 'host', 'ncpus', 'usrname', 'sshport', 'xmlport', 'path' ]
    for line in lines:
        line = line.strip()
        if not line  or  line[0] == '#':
            continue
        splitLine = re.split(r'\s+',line)
        info = splitLine[0]
        hostsInfo = []
        for i in range(len(hostsKeywords)) :
            (val, info) = info.split(':',1)
            hostsInfo.append( val )
            if info == None:
                break

        ifhn = ''  # default
        for kv in splitLine[1:]:
            (k,v) = kv.split('=',1)
            if k == 'ifhn':
                ifhn = v
#        hostsAndInfo.append( {'host' : host, 'ncpus' : ncpus, 'ifhn' : ifhn} )
        tmpdict = { 'ifhn' : ifhn }
        for i in  range(len(hostsKeywords)) :
            tmpdict[hostsKeywords[i]] = hostsInfo[i] if i < len(hostsInfo) else None
        if tmpdict['ncpus'] == None:      # make sure 'ncpus' is not None
            tmpdict['ncpus'] = 1
        hostsAndInfo.append( tmpdict )

    cachedIPs = {}
    if oneMPDPerHost  and  totalnumToStart > 1:
        oldHostsAndInfo = hostsAndInfo[:]
        hostsAndInfo = []
        for hostAndInfo in oldHostsAndInfo:
            oldhost = hostAndInfo['host']
            try:
                ips = gethostbyname_ex(oldhost)[2]    # may fail if invalid host
            except:
                print 'unable to obtain IP for host:', oldhost
                continue
            uips = {}    # unique ips
            for ip in ips:
                uips[ip] = 1
            keep = 1
            for ip in uips.keys():
                if cachedIPs.has_key(ip):
                    keep = 0
                    break
            if keep:
                hostsAndInfo.append(hostAndInfo)
                cachedIPs.update(uips)
    if len(hostsAndInfo) < totalnumToStart:    # one is local
        print 'totalnum=%d  numhosts=%d' % (totalnumToStart,len(hostsAndInfo))
        print 'there are not enough hosts on which to start all processes'
        exit(-1)
    if chkupIndicator:
        hostsToCheck = [ hai['host'] for hai in hostsAndInfo[1:totalnumToStart] ]
        (upList,dnList) = chkupdn(hostsToCheck)
        if dnList:
            print "these hosts are down; exiting"
            print dnList
            exit(-1)
        print "there are %d hosts up (counting local)" % (len(upList)+1)
        if chkupIndicator == 2:  # do the chkup and quit
            exit(0)

    try:
        # stop current (if any) mpds; ignore the output
        getoutput('%s/mpdallexit' % (fullDirName))
        if verbose or debug:
            print 'running mpdallexit on %s' % (myHost)
    except:
        pass

    if environ.has_key('MPD_TMPDIR'):
        tmpdir = environ['MPD_TMPDIR']
    else:
        tmpdir = ''
    if myIfhn:
        ifhn = '--ifhn=%s' % (myIfhn)
    else:
        ifhn = ''
    hostsAndInfo[0]['entry_host'] = ''
    hostsAndInfo[0]['entry_port'] = ''
    mpdArgs = '%s %s --ncpus=%d' % (localConArg,ifhn,myNcpus)
    if tmpdir:
        mpdArgs += ' --tmpdir=%s' % (tmpdir)
    (mpdPID,mpdFD) = launch_one_mpd(0,0,mpdArgs,hostsAndInfo)
    fd2idx = {mpdFD : 0}

    handle_mpd_output(mpdFD,fd2idx,hostsAndInfo)

    try:
        from os import sysconf
        maxfds = sysconf('SC_OPEN_MAX')
    except:
        maxfds = 1024
    maxAtOnce = min(128,maxfds-8)  # -8  for stdeout, etc. + a few more for padding

    hostsSeen = { myHost : 1 }
    fdsToSelect = []
    numStarted = 1  # local already going
    numStarting = 0
    numUnderCurrRoot = 0
    possRoots = []
    currRoot = 0
    idxToStart = 1  # local mpd already going
    while numStarted < totalnumToStart:
        if  numStarting < maxAtOnce  and  idxToStart < totalnumToStart:
            if numUnderCurrRoot < maxUnderOneRoot:
                entryHost = hostsAndInfo[currRoot]['host']
                entryPort = hostsAndInfo[currRoot]['list_port']
                hostsAndInfo[idxToStart]['entry_host'] = entryHost
                hostsAndInfo[idxToStart]['entry_port'] = entryPort
                if hostsSeen.has_key(hostsAndInfo[idxToStart]['host']):
                    remoteConArg = '-n'
                myNcpus = hostsAndInfo[idxToStart]['ncpus']
                ifhn = hostsAndInfo[idxToStart]['ifhn']
                if ifhn:
                    ifhn = '--ifhn=%s' % (ifhn)
                mpdArgs = '%s -h %s -p %s %s --ncpus=%d' % (remoteConArg,entryHost,entryPort,ifhn,myNcpus)
                if tmpdir:
                    mpdArgs += ' --tmpdir=%s' % (tmpdir)
                (mpdPID,mpdFD) = launch_one_mpd(idxToStart,currRoot,mpdArgs,hostsAndInfo)
                numStarting += 1
                numUnderCurrRoot += 1
                hostsAndInfo[idxToStart]['pid'] = mpdPID
                hostsSeen[hostsAndInfo[idxToStart]['host']] = 1
                fd2idx[mpdFD] = idxToStart
                fdsToSelect.append(mpdFD)
                idxToStart += 1
            else:
                if possRoots:
                    currRoot = possRoots.pop()
                    numUnderCurrRoot = 0
            selectTime = 0.01
        else:
            selectTime = 0.1
        try:
            (readyFDs,unused1,unused2) = select(fdsToSelect,[],[],selectTime)
        except error, errmsg:
            mpd_print(1,'mpdboot: select failed: errmsg=:%s:' % (errmsg) )
            exit(-1)
        for fd in readyFDs:
            handle_mpd_output(fd,fd2idx,hostsAndInfo)
            numStarted += 1
            numStarting -= 1
            possRoots.append(fd2idx[fd])
            fdsToSelect.remove(fd)
            fd.close()

def launch_one_mpd(idxToStart,currRoot,mpdArgs,hostsAndInfo):
    global myHost, fullDirName, rshCmd, user, mpdCmd, debug, verbose
    mpdHost = hostsAndInfo[idxToStart]['host']
    if idxToStart == 0:
        cmd = '%s %s -e -d' % (mpdCmd,mpdArgs)
    else:
        if rshCmd == 'ssh':
            rshArgs = '-x -n -q'
        else:
            rshArgs = '-n'
        mpdHost = hostsAndInfo[idxToStart]['host']
        cmd = "%s %s %s '%s %s -e -d' " % \
              (rshCmd,rshArgs,mpdHost,mpdCmd,mpdArgs)
    if verbose:
        entryHost = hostsAndInfo[idxToStart]['entry_host']
        entryPort = hostsAndInfo[idxToStart]['entry_port']
        # print "LAUNCHED mpd on %s  via  %s  %s" % (mpdHost,entryHost,str(entryPort))
        print "LAUNCHED mpd on %s  via  %s" % (mpdHost,entryHost)
    if debug:
        print "debug: launch cmd=", cmd
    mpd = Popen4(cmd,0)
    mpdFD = mpd.fromchild
    mpdPID = mpd.pid
    return (mpdPID,mpdFD)

def handle_mpd_output(fd,fd2idx,hostsAndInfo):
    global myHost, fullDirName, rshCmd, user, mpdCmd, debug, verbose
    idx = fd2idx[fd]
    host = hostsAndInfo[idx]['host']
    # port = fd.readline().strip()
    port = 'no_port'
    for line in fd.readlines():    # handle output from shells that echo stuff
        line = line.strip()
        splitLine = line.split('=')
        if splitLine[0] == 'mpd_port':
            port = splitLine[1]
            break
    if debug:
        print "debug: mpd on %s  on port %s" % (host,port)
    if port.isdigit():
        hostsAndInfo[idx]['list_port'] = int(port)
        tempSock = MPDSock(name='temp_to_mpd')
        try:
            tempSock.connect((host,int(port)))
        except:
            tempSock.close()
            tempSock = 0
        if tempSock:
            msgToSend = { 'cmd' : 'ping', 'ifhn' : 'dummy', 'port' : 0}
            tempSock.send_dict_msg(msgToSend)
            msg = tempSock.recv_dict_msg()    # RMB: WITH TIMEOUT ??
            if not msg  or  not msg.has_key('cmd')  or  msg['cmd'] != 'challenge':
                mpd_print(1,'failed to handshake with mpd on %s; recvd output=%s' % \
                          (host,msg) )
                tempOut = tempSock.recv(1000)
                print tempOut
                try: getoutput('%s/mpdallexit' % (fullDirName))
                except: pass
                exit(-1)
            tempSock.close()
        else:
            mpd_print(1,'failed to connect to mpd on %s' % (host) )
            try: getoutput('%s/mpdallexit' % (fullDirName))
            except: pass
            exit(-1)
    else:
        mpd_print(1,'from mpd on %s, invalid port info:' % (host) )
        print port
        print fd.read()
        try: getoutput('%s/mpdallexit' % (fullDirName))
        except: pass
        exit(-1)
    if verbose:
        print "RUNNING: mpd on", hostsAndInfo[fd2idx[fd]]['host']
    if debug:
        print "debug: info for running mpd:", hostsAndInfo[fd2idx[fd]]

def chkupdn(hostList):
    upList = []
    dnList = []
    for hostname in hostList:
        print 'checking', hostname
        if rshCmd == 'ssh':
            rshArgs = '-x -n'
        else:
            rshArgs = '-n'
        cmd = "%s %s %s /bin/echo hello" % (rshCmd,rshArgs,hostname)
        runner = Popen3(cmd,1,0)
        runout = runner.fromchild
        runerr = runner.childerr
        runin  = runner.tochild
        runpid = runner.pid
        up = 0
        try:
            # (readyFDs,unused1,unused2) = select([runout,runerr],[],[],9)
            (readyFDs,unused1,unused2) = select([runout],[],[],9)
        except:
            print 'select failed'
            readyFDs = []
        for fd in readyFDs:  # may have runout and runerr sometimes
            line = fd.readline()
            if line and line.startswith('hello'):
                up = 1
            else:
                pass
        if up:
            upList.append(hostname)
        else:
            dnList.append(hostname)
        try:
            kill(runpid,SIGKILL)
        except:
            pass
    return(upList,dnList)

def usage():
    print __doc__
    stdout.flush()
    exit(-1)

    
if __name__ == '__main__':
    mpdboot()
