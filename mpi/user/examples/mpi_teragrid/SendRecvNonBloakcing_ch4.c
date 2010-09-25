/* From the Teragrid tutorial : Introduction to MPI
*  http://ci-tutor.ncsa.illinois.edu/
*/

/* deadlock avoided */
#include <stdio.h>
#include <mpi.h>

int main (int argc, char **argv) {

  int myrank;
  MPI_Request request;
  MPI_Status status;
  double a[100], b[100];

  MPI_Init(&argc, &argv);  /* Initialize MPI */
  MPI_Comm_rank(MPI_COMM_WORLD, &myrank); /* Get rank */
  if( myrank == 0 ) {
    /* Post a receive, send a message, then wait */
    MPI_Irecv( b, 100, MPI_DOUBLE, 1, 19, MPI_COMM_WORLD, &request );
    MPI_Send( a, 100, MPI_DOUBLE, 1, 17, MPI_COMM_WORLD );
    MPI_Wait( &request, &status );
  }
  else if( myrank == 1 ) {
    /* Post a receive, send a message, then wait */
    MPI_Irecv( b, 100, MPI_DOUBLE, 0, 17, MPI_COMM_WORLD, &request );   
    MPI_Send( a, 100, MPI_DOUBLE, 0, 19, MPI_COMM_WORLD );
    MPI_Wait( &request, &status );
  }

  MPI_Finalize();          /* Terminate MPI */
  return 0;
}