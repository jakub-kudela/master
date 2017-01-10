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
      -c|--czeng_align)
        CZENG_ALIGN_FILE="$2"
        shift ;;
      -b|--bivec)
        CZENG_BIVEC_DIR="$2"
        shift ;;
      *) ;;
    esac
    shift
  done

  if [ -z "$CZENG_ALIGN_FILE" ] || [ ! -f "$CZENG_ALIGN_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid -c|--czeng_align option!"
    terminate
  fi

  if [ -z "$CZENG_BIVEC_DIR" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid -b|--bivec option!"
    terminate
  fi

  echo ">>> [$SCRIPT][$(date)] Option -c|--czeng_align = $CZENG_ALIGN_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -b|--bivec = $CZENG_BIVEC_DIR."

}

function prepare_temp() {

  TEMP_DIR=$(mktemp -d "$SCRIPT""_XXXXX")
  czeng_align_file_base=$(basename $CZENG_ALIGN_FILE)
  
  TEMP_CS_FILE="$TEMP_DIR"/"$czeng_align_file_base"_cs
  TEMP_EN_FILE="$TEMP_DIR"/"$czeng_align_file_base"_en
  TEMP_ALIGN_FILE="$TEMP_DIR"/"$czeng_align_file_base"_align
  
  echo ">>> [$SCRIPT][$(date)] Temporary folder is $TEMP_DIR."
  
}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
  rm -rf $TEMP_DIR 

  echo ">>> [$SCRIPT][$(date)] Cleaning erroneous output."
  rm -rf $CZENG_BIVEC_DIR

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
awk -F' {##} ' '{print $1}' $CZENG_ALIGN_FILE > $TEMP_EN_FILE
awk -F' {##} ' '{print $2}' $CZENG_ALIGN_FILE > $TEMP_CS_FILE

echo ">>> [$SCRIPT][$(date)] Lowercasing training data."
perl -CSAD -pe '$_=lc' -i $TEMP_DIR/*

echo ">>> [$SCRIPT][$(date)] Replacing numbers in training data."
perl -CSAD -pe 's/[0-9]+/0/g' -i $TEMP_DIR/*

echo ">>> [$SCRIPT][$(date)] Replacing unknown symbols in training data."
perl -CSAD -pe 's/'$UNKNOWN'/'$UNK_TAG'/g' -i $TEMP_DIR/*

echo ">>> [$SCRIPT][$(date)] Preparing training data alignment."
awk -F' {##} ' '{print $3}' $CZENG_ALIGN_FILE > $TEMP_ALIGN_FILE

echo ">>> [$SCRIPT][$(date)] Removing dashes in training data alignment."
perl -CSAD -pe 's/-/ /g' -i $TEMP_ALIGN_FILE

echo ">>> [$SCRIPT][$(date)] Removing trailing spaces in training data alignment."
perl -CSAD -pe 's/ *$//g' -i $TEMP_ALIGN_FILE

echo ">>> [$SCRIPT][$(date)] Preparing output folder."
rm -rf $CZENG_BIVEC_DIR
mkdir -p $CZENG_BIVEC_DIR

echo ">>> [$SCRIPT][$(date)] Running bivec on training data."
( time $BIVEC -src-train $TEMP_EN_FILE -src-lang en \
  -tgt-train $TEMP_CS_FILE -tgt-lang cs \
  -align $TEMP_ALIGN_FILE -align-opt 1 -bi-weight 1.0 \
  -output "$CZENG_BIVEC_DIR"/wordvec \
  -cbow 0 -min-count 3 -size 40 -window 5 -negative 5 -binary 0 -hs 0 \
  -sample 1e-4 -tgt-sample 1e-4 -threads 4 -eval 0 -iter 10 \
) 2>&1 | awk '{ print ">>> [bivec]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
