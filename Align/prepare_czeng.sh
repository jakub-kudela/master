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
      -c|--czeng)
        CZENG_FILE="$2"
        shift ;;
      -cs|--czeng_cs)
        CZENG_CS_FILE="$2"
        shift ;;
      -en|--czeng_en)
        CZENG_EN_FILE="$2"
        shift ;;
      -b|--bin_size)
        BIN_SIZE="$2"
        shift ;;
      *) ;;
    esac
    shift
  done

  if [ -z "$CZENG_FILE" ] || [ ! -f "$CZENG_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid -c|--czeng option!"
    terminate
  fi

  if [ -z "$CZENG_CS_FILE" ] || [ -d "$CZENG_CS_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid --cs|--czeng_cs option!"
    terminate
  fi

  if [ -z "$CZENG_EN_FILE" ] || [ -d "$CZENG_EN_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid -en|--czeng_en option!"
    terminate
  fi

  if [ -z "$BIN_SIZE" ] || ! [ "$BIN_SIZE" -eq "$BIN_SIZE" ]; then
    echo $BIN_SIZE
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid -b|--bin_size option!"
    terminate
  fi

  echo ">>> [$SCRIPT][$(date)] Option -c|--czeng = $CZENG_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -cs|--czeng_cs = $CZENG_CS_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -en|--czeng_en = $CZENG_EN_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -b|--bin_size = $BIN_SIZE."

}

function prepare_temp() {

  TEMP_DIR=$(mktemp -d "$SCRIPT""_XXXXX")
  czeng_file_base=$(basename $CZENG_FILE)

  # TEMP_SORT_FILE="$TEMP_DIR"/"$czeng_file_base"_sort
  TEMP_BIN_ID_FILE="$TEMP_DIR"/"$czeng_file_base"_bin_id
  TEMP_TEXT_CS_FILE="$TEMP_DIR"/"$czeng_file_base"_text_cs
  TEMP_TEXT_EN_FILE="$TEMP_DIR"/"$czeng_file_base"_text_en
  
  echo ">>> [$SCRIPT][$(date)] Temporary folder is $TEMP_DIR."
  
}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
  rm -rf $TEMP_DIR 

  echo ">>> [$SCRIPT][$(date)] Cleaning erroneous output."
  rm -f $CZENG_CS_FILE $CZENG_EN_FILE

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

echo ">>> [$SCRIPT][$(date)] Preparing data."
awk '{printf "%08d\t%d\n", (NR-1)/'$BIN_SIZE', (NR-1)}' $CZENG_FILE > $TEMP_BIN_ID_FILE
cut -f 3 $CZENG_FILE > $TEMP_TEXT_CS_FILE
cut -f 4 $CZENG_FILE > $TEMP_TEXT_EN_FILE

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
paste $TEMP_BIN_ID_FILE $TEMP_TEXT_CS_FILE > $CZENG_CS_FILE
paste $TEMP_BIN_ID_FILE $TEMP_TEXT_EN_FILE > $CZENG_EN_FILE

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
