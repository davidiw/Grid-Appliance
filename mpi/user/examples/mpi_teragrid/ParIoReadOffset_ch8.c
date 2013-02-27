/* From the Teragrid tutorial : Introduction to MPI
*  http://ci-tutor.ncsa.illinois.edu/
*/

#include <stdio.h>
#include <mpi.h>

int main(int argc, char *argv[])
{
  int comm_size,comm_rank;
  int size_int,amode,itest;

  MPI_Datatype etype,filetype;
  MPI_Info info;
  MPI_Status status;
  MPI_File fh;
  MPI_Offset disp;

  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD,&comm_rank);
  MPI_Comm_size(MPI_COMM_WORLD,&comm_size);

  amode=(MPI_MODE_RDONLY);
  size_int=sizeof(size_int);
  info=MPI_INFO_NULL;

  MPI_File_open(MPI_COMM_WORLD,"data.dat",amode,info,&fh);

  disp=comm_rank*size_int;
  etype=MPI_INTEGER;
  filetype=MPI_INTEGER;

/* Try running the program with and without MPI_File_set_view -- 
compare data.dat each time: 
od -c data.dat */  
  MPI_File_set_view(fh,disp,etype,filetype,"native",info);

  MPI_File_read_at(fh,disp,&itest,1,MPI_INTEGER,&status);

  printf("Hello from rank %d. I wrote: %d.n",comm_rank,itest);

  MPI_File_close(&fh);
  MPI_Finalize();
  return 0;
}