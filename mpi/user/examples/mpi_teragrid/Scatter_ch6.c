/* From the Teragrid tutorial : Introduction to MPI
*  http://ci-tutor.ncsa.illinois.edu/
*/

#include <stdio.h>
#include <mpi.h>
int main(int argc, char *argv[]) {
  int rank,size,i;
  double param[8],mine;
  int sndcnt,rcvcnt;
  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD,&rank);
  MPI_Comm_size(MPI_COMM_WORLD,&size);
  rcvcnt=1;
  if(rank==3) {
    for(i=0;i<8;++i) param[i]=23.0+i;
    sndcnt=1;
  }
  MPI_Scatter(param,sndcnt,MPI_DOUBLE,&mine,rcvcnt,MPI_DOUBLE,3,MPI_COMM_WORLD);
  for(i=0;i<size;++i)  {
    if(rank==i) printf("P:%d mine is %f n",rank,mine);
    fflush(stdout);
    MPI_Barrier(MPI_COMM_WORLD);
  }
  MPI_Finalize();
  return 0;
}