/* From the Teragrid tutorial : Introduction to MPI
*  http://ci-tutor.ncsa.illinois.edu/
*/

#include <stdio.h>
#include <mpi.h>

int main (int argc, char **argv) {

  int myrank,i,count;
  MPI_Status status;
  double a[100],b[300];

  MPI_Init(&argc, &argv);  /* Initialize MPI */
  MPI_Comm_rank(MPI_COMM_WORLD, &myrank); /* Get rank */
  if( myrank == 0 ) {        /* Send a message */
    for (i=0;i<100;++i)
         a[i]=sqrt(i);
    MPI_Send( a, 100, MPI_DOUBLE, 1, 17, MPI_COMM_WORLD );
  }else if( myrank == 1 ){   /* Receive a message */
    MPI_Recv( b, 300, MPI_DOUBLE,MPI_ANY_SOURCE,MPI_ANY_TAG, 
                                        MPI_COMM_WORLD, &status );   
    MPI_Get_count(&status,MPI_DOUBLE,&count);
    printf("P:%d message came from rank %dn",myrank,status.MPI_SOURCE);
    printf("P:%d message had tag %dn",myrank,status.MPI_TAG);
    printf("P:%d message size was %dn",myrank,count);
  }


 MPI_Finalize();          /* Terminate MPI */
 return(0);
}