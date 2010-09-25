/* From the Teragrid tutorial : Introduction to MPI
*  http://ci-tutor.ncsa.illinois.edu/
*/

#include <mpi.h>
int main(int argc, char *argv[]) {
	int rank;
	double param;
	MPI_Init(&argc, &argv);
	MPI_Comm_rank(MPI_COMM_WORLD,&rank);
	if(rank==5) param=23.0;
	MPI_Bcast(&param,1,MPI_DOUBLE,5,MPI_COMM_WORLD);
	printf("P:%d after broadcast parameter is %f \n",rank,param);
	MPI_Finalize();
	return 0;
}