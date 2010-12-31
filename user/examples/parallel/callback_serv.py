#!/usr/bin/python

import SimpleXMLRPCServer

class CallbackServ():

    def __init__(self, count, fname, port, debug=0):
        self.count = count              # target number of IPs
        self.curr_count = 0             # ip collected so far
        self.outfname = fname
        self.running = True             # running flag
        self.port = port
        self.debug = debug
#        self.timer = threading.Timer( WAITTIME, self._terminate )
#        self.timer.start()

    # for terminating server
    def _terminate(self):
        self.running = False
        return 0

    # write host's info into a file ( one host per line )
    def write_file(self, data ):

        # construct an entry string from dict 'data'
        entry = data['hostname'] + ":" + data['cpus'] + ":" +  data['usrname'] + ":" + \
                data['sshport'] + ":" + data['xmlport'] + ":" + data['path']

        with open( self.outfname, 'a') as outf:
            outf.write( entry + '\n' )
        outf.closed

        self.curr_count += 1
        if self.debug:
            print 'Received ' + str(self.curr_count) + ' out of ' + \
                str(self.count) + ' responses.'
        if self.curr_count == self.count:    # we reach the target count
            self._terminate()                # no need to wait for timeout
        return 0

    def serv(self):
        server = SimpleXMLRPCServer.SimpleXMLRPCServer(("0.0.0.0", self.port), logRequests = False)
        server.register_function(self.write_file)
        while self.running:
            server.handle_request()
    

