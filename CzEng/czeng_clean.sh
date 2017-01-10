#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
ORIGINAL_IFS=$IFS

NO_LETTER_REGEX="^[^[:alpha:]]*$"

# Script subroutines are listed below:

function handle_options() {

  while [ "$#" -gt 0 ]; do
    case $1 in
      -c|--czeng)
        CZENG_FILE="$2"
        shift ;;
      -m|--min)
        CZENG_MIN_TOKENS="$2"
        shift ;;
      -x|--max)
        CZENG_MAX_TOKENS="$2"
        shift ;;
      *) ;;
    esac
    shift
  done

  if [ -z "$CZENG_FILE" ] || [ ! -f "$CZENG_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -c|--czeng option!"
    exit 1
  fi

  if [ -z "$CZENG_MIN_TOKENS" ] || [[ ! "$CZENG_MIN_TOKENS" =~ ^[0-9]+$ ]]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -m|--min option!"
    exit 1
  fi

  if [ -z "$CZENG_MAX_TOKENS" ] || [[ ! "$CZENG_MAX_TOKENS" =~ ^[0-9]+$ ]]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -x|--max option!"
    exit 1
  fi

  echo ">>> [$SCRIPT][$(date)] Option -c|--czeng = $CZENG_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -m|--min = $CZENG_MIN_TOKENS."
  echo ">>> [$SCRIPT][$(date)] Option -x|--max = $CZENG_MAX_TOKENS."

}

function prepare_temp() {

  TEMP_DIR=$(mktemp -d "$SCRIPT""_XXXXX")
  czeng_file_base=$(basename $CZENG_FILE)

  TEMP_CLEAN_FILE="$TEMP_DIR"/"$czeng_file_base"_clean

  echo ">>> [$SCRIPT][$(date)] Temporary folder is $TEMP_DIR."
  
}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Cleaning erroneous output."
  rm -f $TEMP_DIR

  echo ">>> [$SCRIPT][$(date)] Cleaning environment settings."
  IFS=$ORIGINAL_IFS

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

echo ">>> [$SCRIPT][$(date)] Cleaning CzEng file $CZENG_FILE."
IFS=$'\t'; index=0
too_few_tokens=0; too_many_tokens=0; no_letter=0

while read id prob czech english; do

  if [ $((++index % 100000)) -eq 0 ]; then
    echo ">>> [$SCRIPT][$(date)] Processing entry $index."
  fi

  IFS=' '
  array=( $czech ); czech_words=${#array[@]}
  array=( $english ); english_words=${#array[@]}
  IFS=$'\t'

  if [ $czech_words -lt $CZENG_MIN_TOKENS ] || [ $english_words -lt $CZENG_MIN_TOKENS ]; then
    (( too_few_tokens++ ))
    continue
  fi

  if [ $czech_words -gt $CZENG_MAX_TOKENS ] || [ $english_words -gt $CZENG_MAX_TOKENS ]; then
    (( too_many_tokens++ ))
    continue
  fi

  if [[ $czech =~ $NO_LETTER_REGEX ]] || [[ $english =~ $NO_LETTER_REGEX ]]; then
    (( no_letter++ ))
    continue
  fi

  echo -e "$id\t$prob\t$czech\t$english" >> $TEMP_CLEAN_FILE

done < $CZENG_FILE
IFS=$ORIGINAL_IFS

echo ">>> [$SCRIPT][$(date)] Replacing CzEng file $CZENG_FILE."
mv $TEMP_CLEAN_FILE $CZENG_FILE

echo ">>> [$SCRIPT][$(date)] Excluded $too_few_tokens too-few-tokens entries."
echo ">>> [$SCRIPT][$(date)] Excluded $too_many_tokens too-many-tokens entries."
echo ">>> [$SCRIPT][$(date)] Excluded $no_letter no-letter entries."

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
