This example shows how to compile/link an application to use Condor libraries.
It is based on the tutorial available at:
www.cs.wisc.edu/condor/tutorials

Applications created in this way run in Condor's "standard" universe, which
supports transparent checkpointing and migration - which are very important
features for long-running simulations.

(Applications that are not linked with Condor libraries can still run in
the "vanilla" universe; checkpointing is not supported, however) 

- The simple application that will be used in this tutorial is called simple.c

1) Inspect the application source code. It takes two arguments, sleep_time
and and input. It sleeps for "sleep_time", calculates and prints input*2

2) To "condor-compile" the application: 

condor_compile gcc -o simple.std simple.c

Ignore the warnings that may appear; at the end of the compilation, you should
see a simple.std file in this directory, with approximate size of 12MB (it's
a large file as it includes Condor libraries)

3) Run the application on your local machine, e.g.:
   ./simple.std 5 10
  will sleep for 5 seconds and output a result of 20

4) Submit the application for remote execution; inspect the submit.std file,
   then type: condor_submit simple.sub

  This will submit three different jobs to the Condor pool.

5) Follow the progress of the execution of this application with condor_q.
   [Note that the jobs will take longer than 4 seconds to run, because
   Condor will actually schedule them on remote resources. Condor is well-
   suited for longer-running jobs.]
   Once the application finishes its execution, the output should be written
   to simple.N.out (with a unique N for each job submitted), and a log 
   showing a history of the job in the Condor system should be available in 
   simple.log

