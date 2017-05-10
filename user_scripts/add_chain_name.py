#!/usr/bin/env python

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
