#!/usr/bin/python

import string, os

class TemplateFile:

    def __init__(self, path, fname, outpath, outfname ):
        self.fname = fname
        self.outfname = outfname
        self.path = path
        self.outpath = outpath

    # prepare the output file from keywords in 'kw_list'
    def prepare_file(self, kw_list, set_exec = False ):
        fullname = self._full_name()
        fulloutname = self._full_outname()

        with open( fullname, 'r') as tmpf:
            with open( fulloutname, 'w') as outf:
                for line in tmpf:
                    for entry in kw_list:
                        line = string.replace( line, entry[0], entry[1] )
                    outf.write( line )
        tmpf.close()
        outf.close()

        if set_exec:
            os.chmod( fulloutname, 0755 )

    def _full_name(self):
        return self.path + self.fname

    def _full_outname(self):
        return self.outpath + self.outfname

    def __str__(self):
        return self._full_outname()

    def out_fname(self):
        return self.outfname
