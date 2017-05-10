#!/bin/bash

# trim_traj_files.sh
# script to remove trajectory files (pdb) from MCPU runs
# if 50 runs are done, a lot of space is used.
# removes all but every $EVERY trajectories

HELP="./trim_traj_files.sh -n EVERY DIR"
EVERY=10

while getopts ":hn:" opt; do
  case $opt in
      h) echo "$HELP"; ;;
      n) echo "Trim except for every $OPTARG runs"; EVERY=$OPTARG; ;;
      \?) echo "Invalid option: -$OPTARG" >&2; ;;
  esac
done
shift $((OPTIND-1))

DIR=$1
cd $DIR

TOTALNUM=$(ls -1d run* | wc -l)

for ((i=1; i<=$TOTALNUM; i++)); do
    if [ $(($i % $EVERY)) -eq 0 ]; then
	continue
    fi
    ls -d run_${i}
    rm -rf run_${i}/*.*0 &
    sleep 1
done

wait
