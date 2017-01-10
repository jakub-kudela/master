#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)

TOOLS_DIR="$SCRIPT_DIR"/../Tools
MORPHODITA_TAGGER="$TOOLS_DIR"/morphodita/src/run_tagger
MORPOHODITA_CS_MODEL="$TOOLS_DIR"/morphodita_models/czech-morfflex-pdt-131112/czech-morfflex-pdt-131112.tagger-best_accuracy
MORPOHODITA_EN_MODEL="$TOOLS_DIR"/morphodita_models/english-morphium-wsj-140407/english-morphium-wsj-140407.tagger

PART_SIZE=100000
UNKNOWN='\x{2022}'
ENDLINE='\x{2016}'

# Script subroutines are listed below:

function handle_options() {
  
  while [ "$#" -gt 0 ]; do
    case $1 in
      -c|--cc)
        CC_FILE="$2"
        shift ;;
      -l|--lemma)
        CC_LEMMA_FILE="$2"
        shift ;;
      *) ;;
    esac
    shift
  done

  if [ -z "$CC_FILE" ] || [ ! -f "$CC_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid -c|--cc option!"
    terminate
  fi

  if [ -z "$CC_LEMMA_FILE" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid -l|--lemma option!"
    terminate
  fi

  echo ">>> [$SCRIPT][$(date)] Option -c|--cc = $CC_FILE."
  echo ">>> [$SCRIPT][$(date)] Option -l|--lemma = $CC_LEMMA_FILE."

}

function prepare_temp() {

  TEMP_DIR=$(mktemp -d "$SCRIPT""_XXXXX")
  cc_file_base=$(basename $CC_FILE)

  TEMP_CS_FILE="$TEMP_DIR"/"$cc_file_base"_cs
  TEMP_CS_FILE_PART="$TEMP_DIR"/"$cc_file_base"_cs_
  TEMP_CS_LEMMA_FILE="$TEMP_DIR"/"$cc_file_base"_cs_lemma
  TEMP_CS_INFO_FILE="$TEMP_DIR"/"$cc_file_base"_cs_info
  TEMP_EN_FILE="$TEMP_DIR"/"$cc_file_base"_en
  TEMP_EN_FILE_PART="$TEMP_DIR"/"$cc_file_base"_en_
  TEMP_EN_LEMMA_FILE="$TEMP_DIR"/"$cc_file_base"_en_lemma
  TEMP_EN_INFO_FILE="$TEMP_DIR"/"$cc_file_base"_en_info

  echo ">>> [$SCRIPT][$(date)] Temporary folder is $TEMP_DIR."
  
}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
  rm -rf $TEMP_DIR

  echo ">>> [$SCRIPT][$(date)] Cleaning erroneous output."
  rm -rf $CC_LEMMA_FILE

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

echo ">>> [$SCRIPT][$(date)] Separating Czech part."
awk -F'\t' '{ if ($2 == "cs") print $5 }' $CC_FILE > $TEMP_CS_FILE

echo ">>> [$SCRIPT][$(date)] Splitting Czech part into multiple files."
split -d -l $PART_SIZE $TEMP_CS_FILE $TEMP_CS_FILE_PART
rm -f $TEMP_CS_FILE

echo ">>> [$SCRIPT][$(date)] Replacing unknown symbols in Czech part."
perl -CSAD -pe 's/[^\s\w[:ascii:]]+/'$UNKNOWN'/g' -i $TEMP_CS_FILE_PART*
 
echo ">>> [$SCRIPT][$(date)] Marking line endings in Czech part."
perl -CSAD -pe 's/$/\ '$ENDLINE'/s' -i $TEMP_CS_FILE_PART*

rm -f $TEMP_CS_LEMMA_FILE
for temp_cs_file_part in $TEMP_CS_FILE_PART*; do

  echo ">>> [$SCRIPT][$(date)] Running Tagger on Czech part $temp_cs_file_part."
  ( $MORPHODITA_TAGGER --convert_tagset=strip_lemma_id --output=vertical $MORPOHODITA_CS_MODEL $temp_cs_file_part | tee \
    >( cut -f 2 | tr -s '[:space:]' ' ' | perl -CSAD -pe 's/ *'$ENDLINE' */\n/g' >> $TEMP_CS_LEMMA_FILE ) \
  ) 3>&1 1>&2 2>&3 3>&- > /dev/null | awk '{ print ">>> [morphodita]["strftime()"] " $0; fflush(); }'

  rm -f $temp_cs_file_part

done

echo ">>> [$SCRIPT][$(date)] Separating English part."
awk -F'\t' '{ if ($2 == "en") print $5 }' $CC_FILE > $TEMP_EN_FILE

echo ">>> [$SCRIPT][$(date)] Splitting English part into multiple files."
split -d -l $PART_SIZE $TEMP_EN_FILE $TEMP_EN_FILE_PART
rm -f $TEMP_EN_FILE

echo ">>> [$SCRIPT][$(date)] Replacing unknown symbols in English part."
perl -CSAD -pe 's/[^\s\w[:ascii:]]+/'$UNKNOWN'/g' -i $TEMP_EN_FILE_PART*
 
echo ">>> [$SCRIPT][$(date)] Marking line endings in English part."
perl -CSAD -pe 's/$/\ '$ENDLINE'/s' -i $TEMP_EN_FILE_PART*
 
rm -f $TEMP_EN_LEMMA_FILE
for temp_en_file_part in $TEMP_EN_FILE_PART*; do

  echo ">>> [$SCRIPT][$(date)] Running Tagger on English part $temp_en_file_part."
  ( $MORPHODITA_TAGGER --convert_tagset=strip_lemma_id --output=vertical $MORPOHODITA_EN_MODEL $temp_en_file_part | tee \
    >( cut -f 2 | tr -s '[:space:]' ' ' | perl -CSAD -pe 's/ *'$ENDLINE' */\n/g' >> $TEMP_EN_LEMMA_FILE ) \
  ) 3>&1 1>&2 2>&3 3>&- > /dev/null | awk '{ print ">>> [morphodita]["strftime()"] " $0; fflush(); }'

  rm -f $temp_en_file_part

done

echo ">>> [$SCRIPT][$(date)] Separating Info part."
awk -F'\t' -v OFS='\t' '{ if ($2 == "cs") print $1,$2,$3,$4 }' $CC_FILE > $TEMP_CS_INFO_FILE
awk -F'\t' -v OFS='\t' '{ if ($2 == "en") print $1,$2,$3,$4 }' $CC_FILE > $TEMP_EN_INFO_FILE

echo ">>> [$SCRIPT][$(date)] Generating output file."
paste $TEMP_CS_INFO_FILE $TEMP_CS_LEMMA_FILE > $CC_LEMMA_FILE
paste $TEMP_EN_INFO_FILE $TEMP_EN_LEMMA_FILE >> $CC_LEMMA_FILE

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
