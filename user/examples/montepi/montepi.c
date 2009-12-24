/* calculation of PI */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int main( int argc, char *argv[] )
{
  int    i, N, in_circle;
  double x, y;
  double pi, pi4, error;
  
  if ( argc != 2 )
    exit (1);

  N = atoi( argv[1] );
                                                 /* scan over random numbers */

  srand ( (unsigned long) time(NULL));
  in_circle = 0;

  for ( i=0 ; i<N ; i++ ) {
    x = (double)rand()/(double)RAND_MAX;   /* use 1/4 circle */
    y = (double)rand()/(double)RAND_MAX;
    if ( x*x + y*y <= 1.0 ) {
      in_circle++;
    }
  }
                                                /* pi extrated from ratio of areas */
  pi4 = (double)in_circle / (double) N;
  pi = 4.0 * pi4;
  error = 4 * sqrt( pi4 * ( 1 - pi4 ) / (double) N );
 
  fprintf(stdout, "N = %d\nInCircle = %i\npi = %1.8f\nerror = %1.8f\n", 
                   N, in_circle, pi, error);
}





