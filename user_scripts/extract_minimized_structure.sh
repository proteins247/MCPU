#!/bin/bash

# ./extract_minimized_structure.sh structure_dir trajectory_dir output_dir template

<<'EOF'

After NAMD 5000 step minimization on the structures,
1. Create from template a TCL script to extract minimized structure
2. Call vmd to run script
3. Take output temp pdb and run it through sed to change some aliased names

EOF

echo extract_minimized_structure.sh; echo

. new-modules.sh
module add vmd/1.9.1-fasrc01

structure_directory=$1
trajectory_directory=$2
output_directory=$3
template=$4

if [ ! -d "${output_directory}" ]; then
    echo "Output directory does not exist, exiting"
    exit 10
fi

for pdb in ${structure_directory}/*pdb; do
    fileroot=$(basename ${pdb} .pdb)
    echo "Working on ${fileroot}"
    # coordinates=${structure_directory}/${fileroot}.pdb
    structure=${structure_directory}/${fileroot}.psf
    trajectory=${trajectory_directory}/${fileroot}.dcd
    
    sed \
	-e s:INPSFXXX:"${structure}": \
	-e s:INDCDXXX:"${trajectory}": \
	< "$template" \
	> extract_minimized_structure.tcl
    vmd -dispdev text -e extract_minimized_structure.tcl

    if [ -f MIN_OUT_PDB_TEMP.pdb ]; then
	sed \
	    -e s/HSE/HIS/ \
	    -e "/ILE/ s/CD /CD1/" \
	    < MIN_OUT_PDB_TEMP.pdb \
	    > ${output_directory}/${fileroot}_minimized.pdb
    fi

done
