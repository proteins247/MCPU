#!/bin/bash

# ./run_psfgen.sh structure_input_directory output_directory
echo run_psfgen.sh; echo

. new-modules.sh
module add vmd/1.9.1-fasrc01

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
    
    sed \
	-e s:INPDBXXX:${pdb}: \
	-e s:OUTPSFXXX:"${output_directory}/${fileroot}.psf": \
	-e s:OUTPDBXXX:"${output_directory}/${fileroot}.pdf": \
	< "$template" \
	> generate_topo.pgn

    vmd -dispdev text -e generate_topo.pgn
done
