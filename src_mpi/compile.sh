#!/bin/sh
gcc -O3 -c rng.c
mpicc -O3 -o fold_potential_mpi backbone.c -lm rng.o
