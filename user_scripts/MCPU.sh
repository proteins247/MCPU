#!/bin/bash

module purge
module load gcc/9.2.0-fasrc01 openmpi/4.0.2-fasrc01

srun -n ${SLURM_NTASKS} --mpi=pmix fold_potential_mpi "$@"
