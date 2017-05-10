//start	

MCPU - Monte-Carlo protein simulation program

mcpu_prep - the directory containing the code to create input files
sim - the directory with files prepared for simulations of any specific protein
src_mpi - the directory with source code
src_mpi/cfg - the configuration file
config_files - the directory with parameters


1. Create necessary input files: 
	<PDB_ID>.triple
	<PDB_ID>.sctorsion
	<PDB_ID>.sec_str
To create the first two files, run save_triple.c (in the mcpu_prep directory): 
	./save_triple <PDB_ID>
with triple.energy, sct.energy, and <PDB_ID>.fasta in the directory.

Create <PDB_ID>.sec_str manually. File contains secondary structure assignment for each protein residue (see publication [1]).
first line: use input secondary structure? (9/0 = yes/no)
second line: secondary structure type (H/E/C = helix/sheet/coil)

Place input files, along with the pdb file, in the directory sim/DHFR/files/
(currently contains sample input files for DHFR)


2. Edit path and configuration options. 
- Change all instances of /PATHNAME/ to directory containing the MCPU folder, in configuration file /src_mpi/cfg and in src_mpi/backbone.c.
	Set output directory (PDB_OUT_FILE in cfg and line 9 in backbone.c, in the form /directory/file-prefix)
- Edit configuration options in cfg. The most relevant options (without changing the potential) are:
	NATIVE_FILE and STRUCTURE_FILE -- input PDB file for unfolding simulations (folded structure, single chain, no hydrogens)
	TEMPLATE_FILE, TRIPLET_ENERGY_FILE, SIDECHAIN_TORSION_FILE, SECONDARY_STRUCTURE_FILE 
		-- direct these to the correct input file in the sim folder. 
		- TEMPLATE_FILE is a required blank file, nothing.template.
		- TRIPLET_ENERGY_FILE is <PDB_ID>.triple (see step 1)
		- SIDECHAIN_TORSION_FILE is <PDB_ID>.sctorsion
		- SECONDARY_STRUCTURE_FILE is <PDB_ID>.sec_str
	MC_STEPS -- length of the simulation
	MC_PDB_PRINT_STEPS -- frequency of outputting coordinates to a pdb file
	MC_PRINT_STEPS -- frequency of outputting energies to log file
	MC_REPLICA_STEPS -- frequency of replica exchange. 
		For MCPU simulations (ref. [2]), set to a value greater than MC_STEPS (no replica exchange).
- Edit temperature range if necessary 
	Set minimum temperature: backbone.c, line 14. 
	Currently set so that each processor runs a simulation at a temperature 0.1 units higher than the previous.
	To use a different temperature range, change both backbone.c (line 27) and init.h (function SetProgramOptions, line 52). 


3. Change parameters in define.h if necessary
Contains weights for different energy terms (see publications [1], [3]): 
POTNTL_WEIGHT -- contact potential
HBOND_WEIGHT -- hydrogen bonding
TOR_WEIGHT -- torsional energy for amino acid triplets
SCT_WEIGHT -- side chain torsional energy
ARO_WEIGHT -- relative orientations of aromatic residues


4. Compile and run
The command for code compiling (within src_mpi directory):
mpicc -O3 -o fold_potential_mpi backbone.c -lm
To run:
mpiexec -n <# of procs> ./fold_potential_mpi cfg
	where each processor runs a simulation at a different temperature (32 temperatures were used in ref. [2] for DHFR unfolding)


5. Data analysis
Output PDB file names look like: file-prefix_temperature.MCstep
One log file is output for each simulation temperature: file-prefix_temperature.log
Each log file contains:
total energy (energy), contact number (contact), and rmsd from native structure (rmsd)
which can be used to obtain simulated melting curves (see publication [2]).


Publications:
[1] J.S. Yang et al., Structure 15, 53 (2007)
[2] J. Tian et al., PLOS Comp. Bio., in press
[3] J. Xu, L. Huang, E. I. Shakhnovich, Proteins 79, 1704 (2011)


//end
