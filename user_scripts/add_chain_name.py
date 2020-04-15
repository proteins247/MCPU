#!/usr/bin/env python
"""
add_chain_name.py

The way MCPU prints PDB files, the chain name field is omitted.

My run_MCPU.sh script /used to have/ an awk command that depends on
that field being present. Now it knows to select the appropriate
column, so this script is not that useful to me anymore.

This script modifies the input structure file in place by default

"""


import argparse
import string
import msys


parser = argparse.ArgumentParser()
parser.add_argument("inpdb")
parser.add_argument("--new-name")
args = parser.parse_args()

mol = msys.Load(args.inpdb)

for chain, letter in zip(mol.chains, string.ascii_uppercase):
    chain.name = letter

if args.new_name:
    name = args.new_name
else:
    name = args.inpdb

msys.SavePDB(mol, name)
