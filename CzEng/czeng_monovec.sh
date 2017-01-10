#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)

TOOLS_DIR="$SCRIPT_DIR"/../Tools
BIVEC="$TOOLS_DIR"/bivec/bivec

UNKNOWN='\x{2022}'
UNK_TAG="<unk>"

# Script subroutines are listed below:

function handle_options() {
  
  while [ "$#" -gt 0 ]; do
    case $1 in
      -c|--czeng)
        CZENG_FILE="$2"
        shift ;;
      -m|--monovec)
        CZENG_MONOVEC_DIR="$2"
        shift ;;
      *) ;;
    esac
    shift
  done

  if [ -z "$CZENG_FILE" ] || [ ! -f "$CZENG_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -c|--czeng option!"
    terminate
  fi

  if [ -z "$CZENG_MONOVEC_DIR" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -m|--monovec option!"
    terminate
  fi

  echo ">>> [$SCRIPT][$(date)] Option -c|--czeng = $CZENG_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -m|--monovec = $CZENG_MONOVEC_DIR."

}

function prepare_temp() {

  TEMP_DIR=$(mktemp -d "$SCRIPT""_XXXXX")
  czeng_file_base=$(basename $CZENG_FILE)
  CZENG_MONOVEC_PREFIX="$czeng_file_base"

  TEMP_CS_FILE="$TEMP_DIR"/"$czeng_file_base"_cs
  TEMP_EN_FILE="$TEMP_DIR"/"$czeng_file_base"_en

  echo ">>> [$SCRIPT][$(date)] Temporary folder is $TEMP_DIR."
  
}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
  rm -rf $TEMP_DIR 

  echo ">>> [$SCRIPT][$(date)] Cleaning erroneous output."
  rm -rf $CZENG_MONOVEC_DIR

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

echo ">>> [$SCRIPT][$(date)] Preparing temporary folder."
prepare_temp

echo ">>> [$SCRIPT][$(date)] Preparing training data."
cut -f 3 $CZENG_FILE > $TEMP_CS_FILE
cut -f 4 $CZENG_FILE > $TEMP_EN_FILE

echo ">>> [$SCRIPT][$(date)] Lowercasing training data."
perl -CSAD -pe '$_=lc' -i $TEMP_DIR/*

echo ">>> [$SCRIPT][$(date)] Replacing numbers in training data."
perl -CSAD -pe 's/[0-9]+/0/g' -i $TEMP_DIR/*

echo ">>> [$SCRIPT][$(date)] Replacing unknown symbols in training data."
perl -CSAD -pe 's/'$UNKNOWN'/'$UNK_TAG'/g' -i $TEMP_DIR/*

echo ">>> [$SCRIPT][$(date)] Preparing output folder."
rm -rf $CZENG_MONOVEC_DIR
mkdir -p $CZENG_MONOVEC_DIR

echo ">>> [$SCRIPT][$(date)] Running monovec on Czech training data."
( time $BIVEC \
  -src-train $TEMP_CS_FILE -src-lang cs \
  -output "$CZENG_MONOVEC_DIR"/"$CZENG_MONOVEC_PREFIX" \
  -cbow 0 -min-count 3 -size 40 -window 5 -negative 5 -binary 0 -hs 0 \
  -sample 1e-4 -tgt-sample 1e-4 -threads 1 -eval 0 -iter 10 \
) 2>&1 | awk '{ print ">>> [monovec]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running monovec on English training data."
( time $BIVEC \
  -src-train $TEMP_EN_FILE -src-lang en \
  -output "$CZENG_MONOVEC_DIR"/"$CZENG_MONOVEC_PREFIX" \
  -cbow 0 -min-count 3 -size 40 -window 5 -negative 5 -binary 0 -hs 0 \
  -sample 1e-4 -tgt-sample 1e-4 -threads 1 -eval 0 -iter 10 \
) 2>&1 | awk '{ print ">>> [monovec]["strftime()"] " $0; fflush(); }'
  
echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
