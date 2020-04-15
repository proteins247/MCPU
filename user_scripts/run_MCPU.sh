#!/bin/bash

HELP="run_MCPU.sh [options] input_structure output_directory
  Options:
    -h : help
    -n NPROC : specify number of processors and indirectly
               specify the size of the temperature ladder
    -N NRUNS : specify number of runs to do
    -l LEN   : number of steps in a run
    -e EVERY : save structures for every specified trajectories
    -o FREQ  : save structures every FREQ steps
"
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
   prefix.*, where prefix is the input pdb file minus .pdb suffix
4. Only one instance of this script should be running. Prep script
   save_triple runs in the source dir, and file cfg in the source dir
   also gets modified. Wouldn't want to modify those files while
   things are running.

The number of processors dictates the temperature range of the
simulation because delta T is 0.1, with the
starting temperature being 0.1. So -n 32 is 0.1 to 3.2

@author: victor zhao yzhao01@g.harvard.edu
EOF

# fixed params:
MCPU_PATH=/n/home00/vzhao/opt/MCPU

THREE_TO_ONE="${MCPU_PATH}/user_scripts/three_to_one.sed"

MCPU_CFG_TEMPLATE="${MCPU_PATH}/src_mpi/TEMPLATE.cfg"
# within MCPU, files src_mpi/TEMPLATE.cfg has been edited
#  to accomodate this script.

: ${PARTITION:=shakhnovich,shakgpu,shared}
: ${MEMPERCPU:=500}
: ${ALLOCTIME:=1440}			# 24 hours
: ${NPROC:=32}
: ${NRUNS:=1}
: ${LENGTH:=2000000}
: ${EVERY:=10}                        # Every N runs will save structure trajectories
: ${OUTFREQ:=100000}                  # print pdb file freq

# input arguments
while getopts ":hn:N:l:e:o:" opt; do
    case $opt in
        h) echo "$HELP" >&2; exit ;;
        n) echo "Using $OPTARG processors"; NPROC=$OPTARG; ;;
        N) echo "Number of runs: $OPTARG"; NRUNS=$OPTARG; ;;
        l) echo "Length of run: $OPTARG"; LENGTH=$OPTARG; ;;
        e) echo "Save every $OPTARG trajectories"; EVERY=$OPTARG; ;;
        o) echo "Output pdb every $OPTARG steps"; OUTFREQ=$OPTARG; ;;
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
    echo "$HELP"
    exit 10
fi

if [ ! -f "${input_protein}" ]; then
    echo "Input protein does not exist, exiting"
    echo "$HELP"
    exit 10
fi

input_directory="$(readlink -f $(dirname "$input_protein"))"
fileroot="$(basename "${input_protein}" .pdb)"
input_prefix="${input_directory}/${fileroot}"

if [ ! -d "${output_directory}" ]; then
    mkdir -p ${output_directory}
fi
output_directory=$(readlink -f ${output_directory})

# --------------------------------------------------
# Modules
module purge
source centos7-modules.sh
module load \
       gcc/7.1.0-fasrc01 \
       openmpi/2.1.0-fasrc02 \

# Begin --------------------------------------------------

# Generate required files
# FASTA sequence from PDB
echo ">${fileroot}" > "${input_prefix}.fasta"
grep ATOM < "${input_protein}" \
    | cut -c18-20,23-26 \
    | uniq \
    | awk '{print $1}' \
    | sed -f ${THREE_TO_ONE} \
    | tr -d '\n' \
    | fold \
    >> "${input_prefix}.fasta"
echo >> "${input_prefix}.fasta"
echo "Created ${input_prefix}.fasta"

# Generate .sec_str
n_residues=$(grep ATOM < "${input_protein}" \
		    | awk '{print $4}' \
		    | uniq \
		    | wc -l )
echo $(head -c $n_residues < /dev/zero | tr '\0' '0' ) \
     > "${input_prefix}.sec_str"
echo $(head -c $n_residues < /dev/zero | tr '\0' 'C' ) \
     >> "${input_prefix}.sec_str"
echo "Created ${input_prefix}.sec_str"

# Run save_triple (slowest part of this script)
echo "Running save_triple"
cp "${input_prefix}.fasta" ${MCPU_PATH}/mcpu_prep
echo "change directory: ${MCPU_PATH}/mcpu_prep"; cd ${MCPU_PATH}/mcpu_prep
./save_triple ${fileroot}
yes | mv ${fileroot}.{fasta,triple,sctorsion} "${input_directory}"
echo "Created ${input_prefix}.{triple,sctorsion}"

echo "moving config files to output directory"
cp -rv ${MCPU_PATH}/config_files "${output_directory}"

# For each run
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

    rm -fv "${subdirectory}/nothing.template"
    touch "${subdirectory}/nothing.template"
    echo "Created ${subdirectory}/nothing.template"

    # copy program and run
    cp -v $MCPU_PATH/src_mpi/cfg ${subdirectory}
    cp -v $MCPU_PATH/src_mpi/fold_potential_mpi ${subdirectory}

    echo "change directory: $subdirectory"; cd $subdirectory
	
    echo "Now run program."
    sbatch -p $PARTITION -n $NPROC -t $ALLOCTIME --mem-per-cpu $MEMPERCPU \
	   -J "MCPU_${fileroot}_R${i}" \
	   -o "MCPU_${fileroot}_run${i}.slurm" \
	   --wrap "mpiexec -n $NPROC ./fold_potential_mpi cfg"

    echo "Job submitted, output: ${subdirectory}"
    sleep 0.5
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

NOTES
