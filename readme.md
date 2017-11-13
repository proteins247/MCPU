# MCPU - Monte Carlo protein simulation program

## Directory structure
- `mcpu_prep` - contains code to create input files
- `sim` - example directory with files prepared for simulations
- `src_mpi` - contains source code
- `config_files` - contains parameters
- `user_scripts` - contains scripts to setup MCPU simulations. specific to harvard odyssey

## Quickstart
You may need to compile some code for MCPU to run on your system.

### Compilation
In `mcpu_prep`, compile `save_triple.c`:

    cd mcpu_prep
	gcc -O3 -o save_triple save_triple.c

In `src_mpi`, compile `backbone.c`:

    cd src_mpi
	gcc -c rng.c
	mpicc -O3 -o fold_potential_mpi backbone.c -lm rng.o
	# or call ./compile

### Run simulation

A minimized PDB file is necessary for MCPU simulations. See "Ingredients for Running MCPU."

### Harvard Odyssey

If you are running on Harvard Odyssey, `run_MCPU.sh` (in `user_scripts`) can streamline things. See `./run_MCPU.sh -h` for information.

`user_scripts` contains other scripts to aid in preparing minimized PDB files.

## Ingredients for running MCPU
The follow contains information for setting up MCPU simulations.

### 1. Create necessary input files:
A minimized PDB file is necessary for MCPU. First, some energy files must be generated. Note that `<PDB_ID>` should be substituted with the basename of your structure file (e.g. for `my_protein.pdb`, `<PDB_ID>` is `my_protein`.

Necessary energy files:

	- `<PDB_ID>.triple`
	- `<PDB_ID>.sctorsion`
	- `<PDB_ID>.sec_str`

To create the first two files, run `save_triple` (found in the `mcpu_prep` directory): 

	./save_triple <PDB_ID>

in a directory containing `triple.energy`, `sct.energy`, and `<PDB_ID>.fasta`.

Create `<PDB_ID>.sec_str` manually. File contains secondary structure assignment for each protein residue (see publication [1]).

- first line: use input secondary structure? (9/0 = yes/no)
- second line: secondary structure type (H/E/C = helix/sheet/coil)

It should be sufficient to set every reside to coil-type.

### 2. Edit path and configuration options. 
A configuration file named `cfg` must be created. `src_mpi` contains a `TEMPLATE.cfg` file to be used with `run_MCPU.sh`, a script that streamlines MCPU preparation for Harvard Odyssey users. If you are not on Harvard Odyssey, it is still possible to take `TEMPLATE.cfg` and create your own `cfg` from it by editing all lines that contain `VAR`.

- Edit configuration options in cfg. The most relevant options (without changing the potential) are:
	- NATIVE_FILE and STRUCTURE_FILE -- input PDB file for unfolding simulations (folded structure, single chain, no hydrogens)
	- TEMPLATE_FILE, TRIPLET_ENERGY_FILE, SIDECHAIN_TORSION_FILE, SECONDARY_STRUCTURE_FILE 
		- direct these to the correct input file in the sim folder. 
		- TEMPLATE_FILE is a required blank file, nothing.template.
		- TRIPLET_ENERGY_FILE is <PDB_ID>.triple (see step 1)
		- SIDECHAIN_TORSION_FILE is <PDB_ID>.sctorsion
		- SECONDARY_STRUCTURE_FILE is <PDB_ID>.sec_str
	- MC_STEPS -- length of the simulation
	- MC_PDB_PRINT_STEPS -- frequency of outputting coordinates to a pdb file
	- MC_PRINT_STEPS -- frequency of outputting energies to log file
	- MC_REPLICA_STEPS -- frequency of replica exchange. 
		- For MCPU simulations (ref. [2]), set to a value greater than MC_STEPS (no replica exchange).
- Edit temperature range if necessary 
	- Set minimum temperature: backbone.c, line 14. 
	- Currently set so that each processor runs a simulation at a temperature 0.1 units higher than the previous.
	- To use a different temperature range, change both backbone.c (line 27) and init.h (function SetProgramOptions, line 52). 


### 3. Change parameters in define.h if necessary
Contains weights for different energy terms (see publications [1], [3]): 
- POTNTL_WEIGHT -- contact potential
- HBOND_WEIGHT -- hydrogen bonding
- TOR_WEIGHT -- torsional energy for amino acid triplets
- SCT_WEIGHT -- side chain torsional energy
- ARO_WEIGHT -- relative orientations of aromatic residues


### 4. Compile and run
The command for code compiling (within src_mpi directory):

    mpicc -O3 -o fold_potential_mpi backbone.c -lm

To run:

    mpiexec -n <# of procs> ./fold_potential_mpi cfg

where each processor runs a simulation at a different temperature (32 temperatures were used in ref. [2] for DHFR unfolding)


## Data analysis
Output PDB file names look like: file-prefix_temperature.MCstep
One log file is output for each simulation temperature: file-prefix_temperature.log
Each log file contains:
total energy (energy), contact number (contact), and rmsd from native structure (rmsd)
which can be used to obtain simulated melting curves (see publication [2]).


Publications:
1. J.S. Yang et al., Structure 15, 53 (2007)
2. J. Tian et al., PLOS Comp. Bio., (2015)
3. J. Xu, L. Huang, E. I. Shakhnovich, Proteins 79, 1704 (2011)

