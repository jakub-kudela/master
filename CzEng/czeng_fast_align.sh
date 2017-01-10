#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)

TOOLS_DIR="$SCRIPT_DIR"/../Tools
FAST_ALIGN="$TOOLS_DIR"/fast_align/build/fast_align
ATOOLS="$TOOLS_DIR"/fast_align/build/atools
MERGE_PARAM="$SCRIPT_DIR"/merge_param.py

# Script subroutines are listed below:

function handle_options() {
  
  while [ "$#" -gt 0 ]; do
    case $1 in
      -c|--czeng)
        CZENG_FILE="$2"
        shift ;;
      -a|--align)
        CZENG_ALIGN_DIR="$2"
        shift ;;
      *) ;;
    esac
    shift
  done

  if [ -z "$CZENG_FILE" ] || [ ! -f "$CZENG_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -c|--czeng option!"
    exit 1
  fi

  if [ -z "$CZENG_ALIGN_DIR" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -a|--align option!"
    exit 1
  fi

  echo ">>> [$SCRIPT][$(date)] Option -c|--czeng = $CZENG_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -a|--align = $CZENG_ALIGN_DIR."

}

function prepare_temp() {

  TEMP_DIR=$(mktemp -d "$SCRIPT""_XXXXX")
  czeng_file_base=$(basename $CZENG_FILE)

  TEMP_EN_CS_FILE="$TEMP_DIR"/"$czeng_file_base".en_cs
  EN_CS_PARAM_FILE="$CZENG_ALIGN_DIR"/en_cs.param
  CS_EN_PARAM_FILE="$CZENG_ALIGN_DIR"/cs_en.param
  ALL_PARAM_FILE="$CZENG_ALIGN_DIR"/all.param
  EN_CS_ALIGN_FILE="$CZENG_ALIGN_DIR"/en_cs.align
  CS_EN_ALIGN_FILE="$CZENG_ALIGN_DIR"/cs_en.align
  ALL_ALIGN_FILE="$CZENG_ALIGN_DIR"/all.align

  echo ">>> [$SCRIPT][$(date)] Temporary folder is $TEMP_DIR."
  
}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
  rm -rf $TEMP_DIR 

  echo ">>> [$SCRIPT][$(date)] Cleaning erroneous output."
  rm -rf $CZENG_ALIGN_DIR

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
awk -F'\t' '{ print $4" ||| "$3 }' $CZENG_FILE > $TEMP_EN_CS_FILE

echo ">>> [$SCRIPT][$(date)] Lowercasing training data."
perl -CSAD -pe '$_=lc' -i $TEMP_EN_CS_FILE

echo ">>> [$SCRIPT][$(date)] Preparing output folder."
rm -rf $CZENG_ALIGN_DIR
mkdir -p $CZENG_ALIGN_DIR
  
echo ">>> [$SCRIPT][$(date)] Running forward alignment on training data."
( time $FAST_ALIGN -i $TEMP_EN_CS_FILE -d -o -v -p $EN_CS_PARAM_FILE > $EN_CS_ALIGN_FILE \
) 2>&1 > /dev/null | awk '{ print ">>> [fast_align]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running reverse alignment on training data."
( time $FAST_ALIGN -i $TEMP_EN_CS_FILE -d -o -v -r -p $CS_EN_PARAM_FILE > $CS_EN_ALIGN_FILE \
) 2>&1 > /dev/null | awk '{ print ">>> [fast_align]["strftime()"] " $0; fflush(); }'
  
echo ">>> [$SCRIPT][$(date)] Running atools with 'grow-diag-final-and' method."
( time $ATOOLS -c grow-diag-final-and -i $EN_CS_ALIGN_FILE -j $CS_EN_ALIGN_FILE > $ALL_ALIGN_FILE
) 2>&1 > /dev/null | awk '{ print ">>> [atools]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Merging training parameters."
$MERGE_PARAM -f $EN_CS_PARAM_FILE -r $CS_EN_PARAM_FILE -l -m 0.00001 -o $ALL_PARAM_FILE

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
