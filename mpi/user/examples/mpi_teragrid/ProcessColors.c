/* From the TeraGrid tutorial, Introduction to MPI
 * http://ci-tutor.ncsa.illinois.edu/
 */
#include <stdlib.h>
#include <stdio.h>
#include "mpi.h"

int main (int argc, char* argv[])
{
     int procID, nproc, root, source, target, tag;
     int k, ncolors, pcolor;
     int *colorArray;
     char color[10];
     MPI_Status status;

     // Set the rank 0 process as the root process
     root = 0;

     // Generate three colors for color array, where white = 0, red = 1, and green = 2
     ncolors = 3;
     colorArray = (int*) malloc(sizeof(int) * ncolors);

     for (k = 0; k < ncolors; k++)
     {
          colorArray[k] = k;
     }

     // Initialize MPI
     MPI_Init(&argc, &argv);

     // Get process rank
     MPI_Comm_rank(MPI_COMM_WORLD, &procID);

     // Get total number of processes specificed at start of run
     MPI_Comm_size(MPI_COMM_WORLD, &nproc);

     // Broadcast the array of colors to all processes
     MPI_Bcast(colorArray, ncolors, MPI_INT, root, MPI_COMM_WORLD);     

     // Color each process 'green' (color = 2)
          pcolor = colorArray[2];

     // Have each process send its color to the root process
     tag = pcolor;
     target = 0;

     if (procID != root)
     {
          MPI_Send(&pcolor, 1, MPI_INT, target, tag, MPI_COMM_WORLD);
     }
     else
     {
          for (source = 0; source < nproc; source++)
         {
               if (source != 0)
               {
                    MPI_Recv(&pcolor, 1, MPI_INT, source, tag, MPI_COMM_WORLD, &status);
               }

               switch(pcolor)
               {
                 case 0: sprintf(color, "white");
                         break;
                 case 1: sprintf(color, "red");
                         break;
                 case 2: sprintf(color, "green");
                         break;
                 default: printf("Invalid color\n");
               }    

               printf("proc %d has color %s\n", source, color);
          }
          printf("\n\n");
     }

     pcolor = procID%2;

     if (pcolor == 0)
     {
          sprintf(color, "white");
     }
     else if (pcolor == 1)
     {
          sprintf(color, "red");
     }
     else if (pcolor == 2)                                                    
     {
          sprintf(color, "green");
     }

     // Access new process colors
     if (procID != root)
     {
          MPI_Send(color, 10, MPI_CHAR, root, tag, MPI_COMM_WORLD);
     }
     else
     {
          printf("proc %d has color %s\n", root, color);

          for (source = 1; source < nproc; source++)
          {
               MPI_Recv(color, 10, MPI_CHAR, source, tag, MPI_COMM_WORLD, &status);
               printf("proc %d has color %s\n", source, color);
          }
     }     

     free(colorArray);

     MPI_Finalize();
     return 0;
}