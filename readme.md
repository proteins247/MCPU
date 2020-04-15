# MCPU - Monte Carlo protein simulation program

Monte Carlo Protein Unfolding (MCPU) is a program that performs MC-based protein simulation. It can be used to compute relative changes in melting temperature as a result of point mutations [1]. The software was originally written for protein folding simulation [2]. 

This is repository is my version of the software, originally downloaded from [the Shakhnovich Group website](https://faculty.chemistry.harvard.edu/shakhnovich/software/monte-carlo-protein-unfolding-mcpu). The scripts in this repository are specialized for running on the Harvard Research Computing cluster.

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [MCPU - Monte Carlo protein simulation program](#mcpu---monte-carlo-protein-simulation-program)
    - [Directory structure](#directory-structure)
    - [Melting temperature prediction procedure](#melting-temperature-prediction-procedure)
    - [Quickstart](#quickstart)
        - [Compilation](#compilation)
        - [Run simulation: Harvard cluster](#run-simulation-harvard-cluster)
        - [Run simulation: elsewhere](#run-simulation-elsewhere)
    - [Ingredients for running MCPU](#ingredients-for-running-mcpu)
        - [1. Create necessary input files:](#1-create-necessary-input-files)
        - [2. Edit path and configuration options.](#2-edit-path-and-configuration-options)
        - [3. Change parameters in define.h if necessary](#3-change-parameters-in-defineh-if-necessary)
        - [4. Compile and run](#4-compile-and-run)
    - [Data analysis](#data-analysis)

<!-- markdown-toc end -->


## Directory structure
- `mcpu_prep` - contains code to create input files
- `sim` - example directory with files prepared for simulations
- `src_mpi` - contains source code. `main` is in `backbone.c`
- `config_files` - contains parameters
- `user_scripts` - contains scripts to setup MCPU simulations. 

## Melting temperature prediction procedure
To predict relative changes in melting temperature, the procedure is as follows [1]:

1. Build protein structure
2. Minimize structure using MD simulation (i.e. NAMD 5000 steps). This puts bond lengths and bond angles into optimal geometry since the MC moveset does not adjust these things
3. Minimize the structure using MCPU simulation at temperature 0.1, 2,000,000 steps. Note that MCPU input should be a PDB structure without hydrogens and ligands, and the protein structure should be a single chain.
4. Run unfolding simulations by simulating minimized structure at temperatures of 0.1 through 3.2 in steps of 0.1. Multiple runs should be performed (50?)
5. Average properties like RMSD, energy, and # native contacts across multiple simulations at the same temperature.
6. Fit temperature vs. property curve to find melting temperature.

Melting temperatures can be compared among a family of mutants for the same structure to obtain predictions of relative changes in melting temperature.

## Quickstart
Mainly for running on Harvard Research Computing cluster.

### Compilation
In `mcpu_prep`, compile `save_triple.c`:

    cd mcpu_prep
	gcc -O3 -o save_triple save_triple.c

In `src_mpi`, compile `backbone.c`:

    cd src_mpi
	gcc -O3 -c rng.c
	mpicc -O3 -o fold_potential_mpi backbone.c -lm rng.o
	# or call ./compile

### Run simulation: Harvard cluster
`run_MCPU.sh` (in `user_scripts`) streamlines the process; all that is needed is a minimized structure (PDB) file. See `./run_MCPU.sh -h` for information.

`user_scripts` contains other scripts to aid in preparing minimized PDB files.

### Run simulation: elsewhere
If not running on Harvard Odyssey, it is necessary to read further to understand what components need to be prepared. See "Ingredients for Running MCPU."

## Ingredients for running MCPU
The follow contains information for setting up MCPU simulations.

### 1. Create necessary input files:
A minimized PDB file is necessary for MCPU; the file should not contain hydrogen atoms. From this file, some energy files must be generated. Note that `<PDB_ID>` indicates the basename of your structure file (e.g. for `my_protein.pdb`, `<PDB_ID>` is `my_protein`).

Necessary energy files:

	<PDB_ID>.triple
	<PDB_ID>.sctorsion
	<PDB_ID>.sec_str

To create the first two files, run `save_triple` (found in the `mcpu_prep` directory; may need to recompile)...

	./save_triple <PDB_ID>

...in a directory containing `triple.energy`, `sct.energy`, and `<PDB_ID>.fasta` (this is just a file containing the FASTA sequence of your protein).

Create `<PDB_ID>.sec_str` manually. File contains secondary structure assignment for each protein residue (see publication [2]).

- First line: use input secondary structure? (9/0 = yes/no)
- Second line: secondary structure type (H/E/C = helix/sheet/coil)

In current usage, although the file is needed, filling the first line with as many ``0``s as there are residues is acceptable.

### 2. Edit path and configuration options. 
A configuration file named `cfg` must be created. `src_mpi` contains a `TEMPLATE.cfg` file to be used with `run_MCPU.sh`. If you are not on the Harvard RC cluster, it is still possible to take `TEMPLATE.cfg` and create your own `cfg` from it by editing all lines that contain `VAR`.

- Edit configuration options in `cfg`. The most relevant options (without changing the potential) are:
	- NATIVE_FILE and STRUCTURE_FILE -- path to PDB file for unfolding simulations (folded structure, single chain, no hydrogens)
	- TEMPLATE_FILE, TRIPLET_ENERGY_FILE, SIDECHAIN_TORSION_FILE, SECONDARY_STRUCTURE_FILE 
		- direct these to the correct input file in the sim folder. 
		- TEMPLATE_FILE is a required blank file, `nothing.template`.
		- TRIPLET_ENERGY_FILE is `<PDB_ID>.triple` (see step 1)
		- SIDECHAIN_TORSION_FILE is `<PDB_ID>.sctorsion`
		- SECONDARY_STRUCTURE_FILE is `<PDB_ID>.sec_str`
	- MC_STEPS -- length of the simulation
	- MC_PDB_PRINT_STEPS -- frequency of outputting coordinates to a pdb file
	- MC_PRINT_STEPS -- frequency of outputting energies to log file
	- MC_REPLICA_STEPS -- frequency of replica exchange. 
		- For MCPU simulations (ref. [2]), set to a value greater than MC_STEPS (no replica exchange).
- Edit temperature range if necessary 
	- Set minimum temperature: edit `backbone.c` line 14 and recompile.
	- Currently set so that each processor runs a simulation at a temperature 0.1 units higher than the previous.
	- To use a different temperature range, change both `backbone.c` and `init.h` function, SetProgramOptions. 


### 3. Change parameters in define.h if necessary
Contains weights for different energy terms (see publications [2], [3]): 

- POTNTL_WEIGHT -- contact potential
- HBOND_WEIGHT -- hydrogen bonding
- TOR_WEIGHT -- torsional energy for amino acid triplets
- SCT_WEIGHT -- side chain torsional energy
- ARO_WEIGHT -- relative orientations of aromatic residues


### 4. Compile and run
The command for code compiling (within src_mpi directory):

	gcc -03 -c rng.c
    mpicc -O3 -o fold_potential_mpi backbone.c -lm rng.o

To run:

    mpiexec -n <# of procs> ./fold_potential_mpi cfg

where each processor runs a simulation at a different temperature (32 temperatures were used in ref. [1] for DHFR unfolding)

## Data analysis
Output PDB file names look like: `file-prefix_temperature.MCstep`
One log file is output for each simulation temperature: `file-prefix_temperature.log`
Each log file contains:
total energy (energy), contact number (contact), and rmsd from native structure (rmsd)
which can be used to obtain simulated melting curves (see publication [2]).


Publications:
1. J. Tian et al., PLOS Comp. Bio., (2015)
2. J.S. Yang et al., Structure 15, 53 (2007)
3. J. Xu, L. Huang, E. I. Shakhnovich, Proteins 79, 1704 (2011)
