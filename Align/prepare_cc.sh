#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)

UNKNOWN='\x{2022}'
UNK_TAG="<unk>"

# Script subroutines are listed below:

function handle_options() {
  
  while [ "$#" -gt 0 ]; do
    case $1 in
      -c|--cc)
        CC_FILE="$2"
        shift ;;
      -cs|--cc_cs)
        CC_CS_FILE="$2"
        shift ;;
      -en|--cc_en)
        CC_EN_FILE="$2"
        shift ;;
      *) ;;
    esac
    shift
  done

  if [ -z "$CC_FILE" ] || [ ! -f "$CC_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid -c|--cc option!"
    terminate
  fi

  if [ -z "$CC_CS_FILE" ] || [ -d "$CC_CS_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid -cs|--cc_cs option!"
    terminate
  fi

  if [ -z "$CC_EN_FILE" ] || [ -d "$CC_EN_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid -en|--cc_en option!"
    terminate
  fi

  echo ">>> [$SCRIPT][$(date)] Option -c|--cc = $CC_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -cs|--cc_cs = $CC_CS_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -en|--cc_en = $CC_EN_FILE."

}

function prepare_temp() {

  TEMP_DIR=$(mktemp -d "$SCRIPT""_XXXXX")
  cc_file_base=$(basename $CC_FILE)

  TEMP_SORT_FILE="$TEMP_DIR"/"$cc_file_base"_sort
  TEMP_CS_FILE="$TEMP_DIR"/"$cc_file_base"_cs
  TEMP_EN_FILE="$TEMP_DIR"/"$cc_file_base"_en
  TEMP_BIN_ID_CS_FILE="$TEMP_DIR"/"$cc_file_base"_bin_id_cs
  TEMP_BIN_ID_EN_FILE="$TEMP_DIR"/"$cc_file_base"_bin_id_en
  TEMP_TEXT_CS_FILE="$TEMP_DIR"/"$cc_file_base"_text_cs
  TEMP_TEXT_EN_FILE="$TEMP_DIR"/"$cc_file_base"_text_en

  echo ">>> [$SCRIPT][$(date)] Temporary folder is $TEMP_DIR."
  
}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
  rm -rf $TEMP_DIR 

  echo ">>> [$SCRIPT][$(date)] Cleaning erroneous output."
  rm -f $CC_CS_FILE $CC_EN_FILE

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

echo ">>> [$SCRIPT][$(date)] Presorting data."
LC_ALL=C sort -t$'\t' -k1,1 -s $CC_FILE > $TEMP_SORT_FILE

echo ">>> [$SCRIPT][$(date)] Preparing data."
awk -F"\t" '$2=="cs" {print}' $TEMP_SORT_FILE > $TEMP_CS_FILE
awk -F"\t" '$2=="en" {print}' $TEMP_SORT_FILE > $TEMP_EN_FILE
rm -f $TEMP_SORT_FILE

awk -F"\t" '{printf "%s\t%d\n", $1, (NR-1)}' $TEMP_CS_FILE > $TEMP_BIN_ID_CS_FILE
awk -F"\t" '{printf "%s\t%d\n", $1, (NR-1)}' $TEMP_EN_FILE > $TEMP_BIN_ID_EN_FILE
awk -F"\t" '{print $5}' $TEMP_CS_FILE > $TEMP_TEXT_CS_FILE
awk -F"\t" '{print $5}' $TEMP_EN_FILE > $TEMP_TEXT_EN_FILE
rm -f $TEMP_CS_FILE $TEMP_EN_FILE

echo ">>> [$SCRIPT][$(date)] Lowercasing data."
perl -CSAD -pe '$_=lc' -i $TEMP_TEXT_CS_FILE
perl -CSAD -pe '$_=lc' -i $TEMP_TEXT_EN_FILE

# Replacing number sequences with "0" affects the results of aligning process.
# Beware, bivec word vectors contain only a vector for a zero number.
# echo ">>> [$SCRIPT][$(date)] Replacing numbers in data."
# perl -CSAD -pe 's/[0-9]+/0/g' -i $TEMP_TEXT_CS_FILE
# perl -CSAD -pe 's/[0-9]+/0/g' -i $TEMP_TEXT_EN_FILE

# Replacing unknown symbols with unknown tags does not affect the document vectors that much.
# Beware, it prolongs the length because it changes symbol of length 1 for sequence of length 5.
# echo ">>> [$SCRIPT][$(date)] Replacing unknown symbols in data."
# perl -CSAD -pe 's/'$UNKNOWN'/'$UNK_TAG'/g' -i $TEMP_TEXT_CS_FILE
# perl -CSAD -pe 's/'$UNKNOWN'/'$UNK_TAG'/g' -i $TEMP_TEXT_EN_FILE

echo ">>> [$SCRIPT][$(date)] Creating output files."
paste $TEMP_BIN_ID_CS_FILE $TEMP_TEXT_CS_FILE > $CC_CS_FILE
paste $TEMP_BIN_ID_EN_FILE $TEMP_TEXT_EN_FILE > $CC_EN_FILE

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
