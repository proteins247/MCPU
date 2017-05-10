#!/bin/bash

# ./run_MCPU.sh structure output_directory
echo run_MCPU.sh; echo
<<"EOF"
After preparing minimized protein structures with hydrogen atoms
removed, we are ready to run MCPU.

Based off of the readme.txt instructions as well as
produce_para_remc.pl

1. Requires an input protein as a .pdb file. no hydrogens.
   Single chain!
2. Accompanying input files will be generated in the directory
   containing the input protein.
3. Output will be placed in output_directory, with files named
   prefix.*, where prefix is the fileroot of the input pdb file.
4. Only one instance of this script should be running. File cfg and
   backbone.c in the source get modified, and the executable is
   compiled in the source dir. Wouldn't want to modify those files
   while things are running.

The number of processors dictates the temperature range of the
simulation because delta T is 0.1, with the
starting temperature being 0.1. So -n 32 is 0.2 to 3.2

@author: victor zhao yzhao01@g.harvard.edu
EOF

# Modules
source new-modules.sh
module purge
module load gcc/6.3.0-fasrc01
module load openmpi/2.1.0-fasrc01

# fixed params:
MCPU_PATH=/n/home00/vzhao/opt/MCPU

THREE_TO_ONE=${MCPU_PATH}/user_scripts/three_to_one.sed

# below script assumes no spaces or other weirdness in MCPU_PATH
MCPU_CFG_TEMPLATE=${MCPU_PATH}/src_mpi/TEMPLATE.cfg
MCPU_BACKBONE_TEMPLATE=${MCPU_PATH}/src_mpi/backbone.TEMPLATE.c
# within MCPU, files src_mpi/cfg, src_mpi/backbone.c have been edited
#  to accomodate this script.
# backbone.h char* variables for filenames have been lengthened to 500
# init.h reading cfg file can accomodate 500 chars/line as opposed to 150

PARTITION=shakhnovich
MEMPERCPU=2048
ALLOCTIME=1440			# 24 hours
NPROC=32
NRUNS=1
LENGTH=10000000                 # old default 2 million
EVERY=10
OUTFREQ=1000

# input arguments
while getopts ":n:N:l:e:o:" opt; do
  case $opt in
      n) echo "Using $OPTARG processors"; NPROC=$OPTARG; ;;
      N) echo "Number of runs: $OPTARG"; NRUNS=$OPTARG; ;;
      l) echo "Length of run: $OPTARG"; LENGTH=$OPTARG; ;;
      e) echo "Save every $OPTARG trajectories"; EVERY=$OPTARG; ;;
      o) echo "Output every $OPTARG steps"; OUTFREQ=$OPTARG; ;;
      \?) echo "Invalid option: -$OPTARG" >&2; ;;
  esac
done
shift $((OPTIND-1))

input_protein=$1		# .pdb format please
output_directory=$2

# some checks for files
if [ $# -lt 2 ]; then
    echo "not enough inputs, exiting"
    echo "required: input_protein output_directory"
    exit 10
fi

if [ ! -f "${input_protein}" ]; then
    echo "Input protein does not exist, exiting"
    exit 10
fi

input_directory=$(readlink -f $(dirname "$input_protein"))
fileroot=$(basename "${input_protein}" .pdb)
input_prefix="${input_directory}/${fileroot}"

if [ ! -d "${output_directory}" ]; then
    mkdir -p ${output_directory}
fi
output_directory=$(readlink -f ${output_directory})

# Begin --------------------------------------------------

# preprocess pdb
# this modifies PDB file in place!!!!!!!!!!!!!
/n/home00/vzhao/opt/MCPU/user_scripts/add_chain_name.py "${input_protein}"

# generate required files
# FASTA sequence from PDB
echo ">${fileroot}" > "${input_prefix}.fasta"
grep ATOM < "${input_protein}" \
    | awk '{print $4,$6}' \
    | uniq \
    | awk '{print $1}' \
    | sed -f ${THREE_TO_ONE} \
    | tr -d '\n' \
    | fold \
    >> "${input_prefix}.fasta"
echo >> "${input_prefix}.fasta"
echo "Created ${input_prefix}.fasta"

# generate .sec_str
n_residues=$(grep ATOM < "${input_protein}" \
		    | awk '{print $4}' \
		    | uniq \
		    | wc -l )
echo $(head -c $n_residues < /dev/zero | tr '\0' '0' ) \
     > "${input_prefix}.sec_str"
echo $(head -c $n_residues < /dev/zero | tr '\0' 'C' ) \
     >> "${input_prefix}.sec_str"
echo "Created ${input_prefix}.sec_str"

# run save_triple
echo "Running save_triple"
cp "${input_prefix}.fasta" ${MCPU_PATH}/mcpu_prep
echo "change directory: ${MCPU_PATH}/mcpu_prep"; cd ${MCPU_PATH}/mcpu_prep
./save_triple ${fileroot}
yes | mv ${fileroot}.{fasta,triple,sctorsion} "${input_directory}"
echo "Created ${input_prefix}.{triple,sctorsion}"

echo "moving config files to output directory"
cp -rv ${MCPU_PATH}/config_files "${output_directory}"

# for each run
for ((i=0; i<$NRUNS; i++)); do
    # make subdirectory
    subdirectory="${output_directory}/run_${i}"
    mkdir "${subdirectory}"
    
    if [ $(($i % $EVERY)) -eq 0 ]; then
	PRINT_PDB=1
    else
        PRINT_PDB=0
    fi

    # configure files
    sed \
	-e "s:VAR_OUTPUT:${subdirectory}/${fileroot}:" \
	-e "s:VAR_TEMPLATE:${subdirectory}:" \
	-e "s:VAR_INPUT:${input_prefix}:" \
	-e "s:VAR_STEPS:${LENGTH}:" \
	-e "s:VAR_PRINT:${PRINT_PDB}:" \
	-e "s:VAR_OUTFREQ:${OUTFREQ}:" \
	< $MCPU_CFG_TEMPLATE \
	> $MCPU_PATH/src_mpi/cfg
    echo "Created protein-specific $MCPU_PATH/src_mpi/cfg"
    sed \
	-e "s:VAR_OUTPUT:${subdirectory}/${fileroot}:" \
	< $MCPU_BACKBONE_TEMPLATE \
	> $MCPU_PATH/src_mpi/backbone.c
    echo "Created protein specific $MCPU_PATH/src_mpi/backbone.c"

    rm -fv "${subdirectory}/nothing.template"
    touch "${subdirectory}/nothing.template"
    echo "Created ${subdirectory}/nothing.template"

    # now compile and run
    echo "Compile"
    echo "change directory: $MCPU_PATH/src_mpi"; cd $MCPU_PATH/src_mpi
    mpicc -O3 -o ${subdirectory}/fold_potential_mpi backbone.c -lm
    cp -v cfg ${subdirectory}

    echo "change directory: $subdirectory"; cd $subdirectory
	
    echo "Compiled. Now running."
    sbatch -p $PARTITION -n $NPROC -t $ALLOCTIME --mem-per-cpu $MEMPERCPU \
	   -J "MCPU_R${i}_${fileroot}" \
	   -o "submit_MCPU_${fileroot}_run${i}.log" \
	   --wrap "mpiexec -n $NPROC ./fold_potential_mpi cfg"

    echo "Job submitted, output: ${subdirectory}"
done

<<NOTES

What's needed is an "installation" of MCPU in which everything is
configured properly. 

0. Put it in a fixed path location.
1. Change /PATHNAME/ instances to the path in config files
2. Set output directory
3. Edit configuration files to taste
4. I think some configuration settings have to be left at run time?
5. define.h parameters probably are fine?
6. Each time to run software needs separate compilation?

NOTES
