#!/bin/bash

# ./pdb_to_sequence.sh [-t] PDBFILE
echo pdb_to_sequence.sh >&2
<<"EOF"
Convert PDB file to amino acid sequence.

1 letter sequence by default.
Option -t will do three letter sequence

@author: victor zhao yzhao01@g.harvard.edu
EOF

# Modules
. new-modules.sh

# fixed params:
THREE_TO_ONE=/n/home00/vzhao/shakhnovich_scripts/three_to_one.sed
THREE=0

# input arguments
while getopts ":thf:" opt; do
  case $opt in
      t) echo "Three letter resnames" >&2; THREE=1; ;;
      f) echo "line breaks at $OPTARG characters" >&2; FOLD=$OPTARG; ;;
      h) echo "Help: pdb_to_sequence.sh [-t] [-h] [-f N] PDBFILE" >&2; exit 5; ;;
      \?) echo "Invalid option: -$OPTARG" >&2
	  echo "Help: pdb_to_sequence.sh [-t] [-h] [-f N] PDBFILE" >&2; exit 5; ;;
  esac
done
shift $((OPTIND-1))

if [ $# -lt 1 ]; then
    echo "Help: pdb_to_sequence.sh [-t] [-h] [-f N] PDBFILE" >&2
    echo "no input; exiting" >&2
    exit 5
fi

PDBFILE=$1
grep '^ATOM' < "${PDBFILE}" \
    | awk '{print $4,$6}' \
    | uniq \
    | awk '{print $1}' \
    | $([ $THREE -eq 0 ] && echo "sed -f ${THREE_TO_ONE} " || echo "cat" ) \
    | tr -d '\n' \
    | $([ -n "$FOLD" ] && echo "fold -w $FOLD" || echo "cat")
echo
