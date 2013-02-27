/* From the Teragrid tutorial : Introduction to MPI
*  http://ci-tutor.ncsa.illinois.edu/
*/

/************************************
      Conway Game of Life

 4 processors, domain decomposition
 in both i and j directions

*************************************/

#include "mpi.h"
#include <stdio.h>
#include <stdlib.h>

#define NI 200
#define NJ 200
#define NSTEPS 500

int main(int argc, char *argv[]){

  int i, j, n, im, ip, jm, jp, nsum, isum, isum1, nprocs ,myid;
  int ig, jg, i1g, i2g, j1g, j2g, ninom, njnom, ninj, 
      i1, i2, j1, j2, ni, nj, i2m, j2m;
  int niproc, njproc, isumloc;
  int proc_north, proc_south, proc_east, proc_west, 
      proc_ne, proc_nw, proc_se, proc_sw;
  int **old, **new, *old1d, *new1d;
  MPI_Status status;
  MPI_Datatype column_type;
  MPI_Request request[16];
  float x;

  /* initialize MPI */

  MPI_Init(&argc,&argv);
  MPI_Comm_size(MPI_COMM_WORLD,&nprocs);
  MPI_Comm_rank(MPI_COMM_WORLD,&myid);

  /* nominal number of i and j points per proc. (without ghost cells,
     assume numbers divide evenly) */

  if(nprocs == 1){
    niproc = 1;
    njproc = 1;
  }else{
    niproc = nprocs/2;
    njproc = nprocs/2;
  }
  ninom = NI/niproc;
  njnom = NJ/njproc;

  /* For transferring data, define processor number
     above (north), below (south), to the right (east), 
     and to the left (west) of the current processor.
     Note that when there are only 2 rows of processors,
     north and south will be equal due to periodicity
    (same for 2 columns for east and west). */

  if(nprocs > 1){
    switch(myid){
    case 0:
      proc_north = 2;
      proc_south = 2;
      proc_east  = 1;
      proc_west  = 1;
      proc_nw    = 3;
      proc_ne    = 3;
      proc_se    = 3;
      proc_sw    = 3;
      break;
    case 1:
      proc_north = 3;
      proc_south = 3;
      proc_east  = 0;
      proc_west  = 0;
      proc_nw    = 2;
      proc_ne    = 2;
      proc_se    = 2;
      proc_sw    = 2;
      break;
    case 2:
      proc_north = 0;
      proc_south = 0;
      proc_east  = 3;
      proc_west  = 3;
      proc_nw    = 1;
      proc_ne    = 1;
      proc_se    = 1;
      proc_sw    = 1;
      break;
    case 3:
      proc_north = 1;
      proc_south = 1;
      proc_east  = 2;
      proc_west  = 2;
      proc_nw    = 0;
      proc_ne    = 0;
      proc_se    = 0;
      proc_sw    = 0;
    }
  }

  /* local starting and ending index, including 2 ghost cells
     (one at bottom, one at top) */

  i1  = 0;
  i2  = ninom + 1;
  i2m = i2 - 1;
  j1  = 0;
  j2  = njnom + 1;
  j2m = j2 - 1;
  
  
  /* global starting and ending indices (without ghost cells) */

  i1g = (myid/2)*ninom + 1;
  j1g = (myid%2)*njnom + 1;
  i2g = i1g + ninom - 1;
  j2g = j1g + njnom - 1;

  /* allocate arrays; want elements to be contiguous,
     so allocate 1-D arrays, then set pointer to each row
     (old and new) to allow use of array notation for convenience */

  ni = i2-i1+1;
  nj = j2-j1+1;
  ninj = ni*nj;  /* number of points on current processor */

  old1d = malloc(ninj*sizeof(int));
  new1d = malloc(ninj*sizeof(int));
  old   = malloc(ni*sizeof(int*));  /* allocate pointers to rows */
  new   = malloc(ni*sizeof(int*));

  for(i=0; i<ni; i++){      /* set row pointers to appropriate */
    old[i] = &old1d[i*nj];  /* locations in 1-D arrays         */
    new[i] = &new1d[i*nj];
  }

  /*  Initialize elements of old to 0 or 1.
      We're doing some sleight of hand here to make sure we
      initialize to the same values as in the serial case.
      The rand() function is called for every i and j, even
      if they are not on the current processor, to get the same
      random distribution as the serial case, but they are
      only used if i and j reside on the current procesor. */

  for(ig=1; ig<=NI; ig++){
    for(jg=1; jg<=NJ; jg++){
      x = rand()/((float)RAND_MAX + 1);

      /* if this ig and jg are on the current processor */
      if( ig >= i1g && ig <= i2g && jg >= j1g && jg <= j2g ){

        /* local i and j indices, accounting for lower ghost cell */
        i = ig - i1g + 1;
        j = jg - j1g + 1;

        if(x<0.5){
          old[i][j] = 0;
        }else{
          old[i][j] = 1;
        }
      }

    }
  }

  /* Create derived type for single column of array.
     There are ninom "blocks," each containing 1 element,
     with a stride of nj between the blocks */

  MPI_Type_vector(ninom , 1, nj, MPI_INT, &column_type);
  MPI_Type_commit(&column_type);

  /* iterate */

  for(n=0; n<NSTEPS; n++){

    /* copy or transfer data to ghost cells */

    if(nprocs == 1){
      for(i=1; i<i2; i++){          /* left and right columns */
        old[i][0]  = old[i][j2m];
        old[i][j2] = old[i][1];
      }
      for(j=1; j<j2; j++){          /* top and bottom rows */
        old[0][j]  = old[i2m][j];
        old[i2][j] = old[1][j];
      }
      old[0][0]   = old[i2m][j2m];  /* corners */
      old[0][j2]  = old[i2m][1];
      old[i2][0]  = old[1][j2m];
      old[i2][j2] = old[1][1];
    }else{

      /* send and receive left and right columns using
         our derived type "column_type" */

      MPI_Isend(&old[1][j2m],  1, column_type, 
                proc_east,  0, MPI_COMM_WORLD, &request[0]);
      MPI_Irecv(&old[1][j2],    1, column_type, 
                proc_east,  1, MPI_COMM_WORLD, &request[1]);
      MPI_Isend(&old[1][1],    1, column_type, 
                proc_west,  1, MPI_COMM_WORLD, &request[2]);
      MPI_Irecv(&old[1][0],     1, column_type, 
                proc_west,  0, MPI_COMM_WORLD, &request[3]);

      /* send and receive top and bottom rows */

      MPI_Isend(&old[i2m][1],  njnom,  MPI_INT,   
                proc_south, 0, MPI_COMM_WORLD, &request[4]);
      MPI_Irecv(&old[i2][1],    njnom,  MPI_INT,   
                proc_south, 1, MPI_COMM_WORLD, &request[5]);
      MPI_Isend(&old[1][1],    njnom,  MPI_INT,  
                proc_north, 1, MPI_COMM_WORLD, &request[6]);
      MPI_Irecv(&old[0][1],     njnom,  MPI_INT,   
                proc_north, 0, MPI_COMM_WORLD, &request[7]);

      /* send and receive corners */

      MPI_Isend(&old[1][1], 1, MPI_INT, 
                proc_nw, 10, MPI_COMM_WORLD, &request[8]);
      MPI_Irecv( &old[0][0], 1, MPI_INT,
                proc_nw, 12, MPI_COMM_WORLD, &request[9]);
      MPI_Isend(&old[1][j2m], 1, MPI_INT, 
                proc_ne, 11, MPI_COMM_WORLD, &request[10]);
      MPI_Irecv( &old[0][j2], 1, MPI_INT,
                proc_ne, 13, MPI_COMM_WORLD, &request[11]);
      MPI_Isend(&old[i2m][j2m], 1, MPI_INT, 
                proc_se, 12, MPI_COMM_WORLD, &request[12]);
      MPI_Irecv( &old[i2][j2], 1, MPI_INT,
                proc_se, 10, MPI_COMM_WORLD, &request[13]);
      MPI_Isend(&old[i2m][1], 1, MPI_INT, 
                proc_sw, 13, MPI_COMM_WORLD, &request[14]);
      MPI_Irecv( &old[i2][0], 1, MPI_INT,
                proc_sw, 11, MPI_COMM_WORLD, &request[15]);

      /* Make sure all non-blocking messages have arrived */

      for(i=0; i<16; i++){
        MPI_Wait(&request[i],&status);
      }
    }

    /* update states of cells */

    for(i=1; i<i2; i++){
      for(j=1; j<j2; j++){
                
        /* Periodic boundary conditions are
           maintained through ghost cells. */

        im = i-1;
        ip = i+1;
        jm = j-1;
        jp = j+1;
        nsum =  old[im][jp] + old[i][jp] + old[ip][jp]
              + old[im][j ]              + old[ip][j ] 
              + old[im][jm] + old[i][jm] + old[ip][jm];

        switch(nsum){
        case 3:
          new[i][j] = 1;
          break;
        case 2:
          new[i][j] = old[i][j];
          break;
        default:
          new[i][j] = 0;
        }
      }
    }

    /* copy new state into old state */
    
    for(i=1; i<i2; i++){
      for(j=1; j<j2; j++){
        old[i][j] = new[i][j];
      }
    }
  }

  /*  Iterations are done; sum the number of live cells */

  isum = 0;
  for(i=1; i<i2; i++){
    for(j=1; j<j2; j++){
      isum = isum + new[i][j];
    }
  }

  /* Print final number of live cells.  For multiple processors,
     must reduce partial sums */
  
  if(nprocs > 1){
    isumloc = isum;
    MPI_Reduce(&isumloc, &isum, 1, MPI_INT, MPI_SUM, 0, MPI_COMM_WORLD);
  }
  if(myid == 0) printf("nNumber of live cells = %dnn", isum);
  
  MPI_Finalize();
  return 0;
}
