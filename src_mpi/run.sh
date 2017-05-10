#! /bin/bash

#SBATCH -n 32
#SBATCH -t 2000 
#SBATCH -p general 
#SBATCH --mem=15000 

mpiexec -n 16 ./fold_potential_mpi ./cfg > out.txt 32> err.txt 
