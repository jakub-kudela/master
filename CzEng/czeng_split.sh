#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)

# Script subroutines are listed below:

function handle_options() {

  while [ "$#" -gt 0 ]; do
    case $1 in
      -c|--czeng)
        CZENG_FILE="$2"
        shift ;;
      -h|--head)
        CZENG_HEAD_FILE="$2"
        shift ;;
      -t|--tail)
        CZENG_TAIL_FILE="$2"
        shift ;;
      -r|--ratio)
        CZENG_HEAD_RATIO="$2"
        shift ;;
      *) ;;
    esac
    shift
  done

  if [ -z "$CZENG_FILE" ] || [ ! -f "$CZENG_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -c|--czeng option!"
    exit 1
  fi

  if [ -z "$CZENG_HEAD_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -h|--head option!"
    exit 1
  fi

  if [ -z "$CZENG_TAIL_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -t|--tail option!"
    exit 1
  fi

  if [ -z "$CZENG_HEAD_RATIO" ] || [[ ! "$CZENG_HEAD_RATIO" =~ ^[0-9]+$ ]]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -r|--ratio option!"
    exit 1
  fi

  echo ">>> [$SCRIPT][$(date)] Option -c|--czeng = $CZENG_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -h|--head = $CZENG_HEAD_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -t|--tail = $CZENG_TAIL_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -r|--ratio = $CZENG_HEAD_RATIO."

}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Cleaning erroneous output."
  rm -f $CZENG_HEAD_FILE $CZENG_TAIL_FILE

  echo ">>> [$SCRIPT][$(date)] Script ended unsucessfully!"
  trap - EXIT TERM INT
  exit 1

}

# Script execution starts below:

echo ">>> [$SCRIPT][$(date)] Handling command line options."
handle_options "$@"

echo ">>> [$SCRIPT][$(date)] Starting execution in $PWD."
trap terminate EXIT TERM INT
cd $PWD

echo ">>> [$SCRIPT][$(date)] Reading file while counting lines."
all_lines=$(wc -l < $CZENG_FILE)
head_lines=$(($all_lines * $CZENG_HEAD_RATIO / 100)); 
tail_lines=$(($all_lines - $head_lines))

echo ">>> [$SCRIPT][$(date)] Creating head with $head_lines entries."
head -n $head_lines $CZENG_FILE > $CZENG_HEAD_FILE

echo ">>> [$SCRIPT][$(date)] Creating tail with $tail_lines entries."
tail -n $tail_lines $CZENG_FILE > $CZENG_TAIL_FILE

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
