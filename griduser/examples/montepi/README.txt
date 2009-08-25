montepi.c contains a Monte Carlo estimator for PI.  Following the semantics of the code the idea is to take N random pairs and see if they fit within a circle.  In the end the ratio of those in the circle over the total is the estimate of PI.

The application takes one input, which is the N random number of pairs.

Ex:

./montepi 1000

To compile:
gcc montepi.c -o montepi -lm

To compile with Condor's libraries:
condor_compile gcc montepi.c -o montepi.cnd -lm

To submit the job without taking advantage of the Condor library features:
condor_submit submit_montepi_vanilla

To submit the job taking advantage of the Condor library features (must have been compiled with the Condor libraries):
condor_submit submit_montepi_standard

More information is available in the above files 

Note: "-lm" includes the math library associated with "Math.h" in the C program.
