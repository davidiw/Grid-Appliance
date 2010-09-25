/* From the Teragrid tutorial : Introduction to MPI
*  http://ci-tutor.ncsa.illinois.edu/
*/

#include <stdio.h>
#include <mpi.h>

int main(int argc, char *argv[])
{
  int comm_size,comm_rank;
  int size_int,amode;
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

  amode=(MPI_MODE_CREATE|MPI_MODE_WRONLY);
  size_int=sizeof(size_int);
  info=0;

  MPI_File_open(MPI_COMM_WORLD,fname,amode,info,&fh);

  disp=comm_rank*size_int;
  etype=MPI_INTEGER;
  filetype=MPI_INTEGER;

  MPI_File_set_view(fh,disp,etype,filetype,drep,info);

  MPI_File_write(fh,&comm_rank,1,MPI_INTEGER,&status);

  printf("Hello from rank %d. I wrote: %d.n",comm_rank,comm_rank);

  MPI_File_close(&fh);
  MPI_Finalize();
  return 0;
}
