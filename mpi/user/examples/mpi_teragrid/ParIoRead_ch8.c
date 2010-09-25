/* From the Teragrid tutorial : Introduction to MPI
*  http://ci-tutor.ncsa.illinois.edu/
*/

#include <stdio.h>
#include <mpi.h>

int main(int argc, char *argv[])
{
  int comm_size,comm_rank;
  int size_int,amode,itest;
  char *fname,*drep;

  MPI_Datatype etype,filetype;
  MPI_Info info;
  MPI_Status status;
  MPI_File fh;
  MPI_Offset disp;

  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD,&comm_rank);
  MPI_Comm_size(MPI_COMM_WORLD,&comm_size);

  fname="data.dat";
  drep="native";

  amode=(MPI_MODE_RDONLY);
  size_int=sizeof(size_int);
  info=0;

  MPI_File_open(MPI_COMM_WORLD,fname,amode,info,&fh);

  disp=comm_rank*size_int;
  etype=MPI_INTEGER;
  filetype=MPI_INTEGER;

  MPI_File_set_view(fh,disp,etype,filetype,drep,info);

  MPI_File_read(fh,&itest,1,MPI_INTEGER,&status);

  printf("Hello from rank %d. I read: %d.n",comm_rank,itest);

  MPI_File_close(&fh);
  MPI_Finalize();
  return 0;
}