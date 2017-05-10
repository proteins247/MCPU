#!/bin/bash

# ./run_namd_min.sh structure_input_directory output_directory template
# Minimization for multiple structures in one directory
# single core

echo run_namd_min.sh; echo

. new-modules.sh
module add legacy/0.0.1-fasrc01
module add hpc/namd-2.9

input_directory=$1
output_directory=$2
template=$3

if [ ! -d "${output_directory}" ]; then
    echo "Output directory does not exist, exiting"
    exit 10
fi

for pdb in ${input_directory}/*pdb; do
    echo "Working on ${pdb}"
    fileroot=$(basename ${pdb} .pdb)
    coordinates=${input_directory}/${fileroot}.pdb
    structure=${input_directory}/${fileroot}.psf
    
    sed \
	-e s:XXXINPSF:"${structure}": \
	-e s:XXXINPDB:"${coordinates}": \
	-e s:XXXOUTROOT:"${output_directory}/${fileroot}": \
	< "$template" \
	> "${output_directory}/namd_minimization_${fileroot}.conf"

    sbatch -p shakhnovich -n 1 -t 360 -o ${output_directory}/${fileroot}.log \
    	   --wrap "namd2 ${output_directory}/namd_minimization_${fileroot}.conf"
done
