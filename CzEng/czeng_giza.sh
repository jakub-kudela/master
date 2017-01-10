#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)

TOOLS_DIR="$SCRIPT_DIR"/../Tools
GIZA_PP="$TOOLS_DIR"/giza-pp/GIZA++-v2/GIZA++
PLAIN_2_SNT_OUT="$TOOLS_DIR"/giza-pp/GIZA++-v2/plain2snt.out
SNT_2_COOC_OUT="$TOOLS_DIR"/giza-pp/GIZA++-v2/snt2cooc.out
MKCLS="$TOOLS_DIR"/giza-pp/mkcls-v2/mkcls

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

  TEMP_CS_FILE="$TEMP_DIR"/"$czeng_file_base"_cs
  TEMP_CS_VCB_FILE="$TEMP_DIR"/"$czeng_file_base"_cs.vcb
  TEMP_CS_VCB_CLASSES_FILE="$TEMP_DIR"/"$czeng_file_base"_cs.vcb.classes
  TEMP_EN_FILE="$TEMP_DIR"/"$czeng_file_base"_en
  TEMP_EN_VCB_FILE="$TEMP_DIR"/"$czeng_file_base"_en.vcb
  TEMP_EN_VCB_CLASSES_FILE="$TEMP_DIR"/"$czeng_file_base"_en.vcb.classes
  TEMP_EN_CS_SNT_FILE="$TEMP_DIR"/"$czeng_file_base"_en_"$czeng_file_base"_cs.snt
  TEMP_EN_CS_COOC_FILE="$TEMP_DIR"/"$czeng_file_base"_en_"$czeng_file_base"_cs.cooc
  
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
cut -f 3 $CZENG_FILE > $TEMP_CS_FILE
cut -f 4 $CZENG_FILE > $TEMP_EN_FILE

echo ">>> [$SCRIPT][$(date)] Lowercasing training data."
perl -CSAD -pe '$_=lc' -i $TEMP_DIR/*

echo ">>> [$SCRIPT][$(date)] Preparing output folder."
rm -rf $CZENG_ALIGN_DIR
mkdir -p $CZENG_ALIGN_DIR

echo ">>> [$SCRIPT][$(date)] Running mkcls on Czech training data."
( time $MKCLS -p$TEMP_CS_FILE -V$TEMP_CS_VCB_CLASSES_FILE \
) 2>&1 | awk '{ print ">>> [mkcls]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running mkcls on English training data."
( time $MKCLS -p$TEMP_EN_FILE -V$TEMP_EN_VCB_CLASSES_FILE \
) 2>&1 | awk '{ print ">>> [mkcls]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running plain2snt.out on training data."
( time $PLAIN_2_SNT_OUT $TEMP_EN_FILE $TEMP_CS_FILE \
) 2>&1 | awk '{ print ">>> [plain2snt.out]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running snt2cooc.out on training data."
( time $SNT_2_COOC_OUT $TEMP_EN_VCB_FILE $TEMP_CS_VCB_FILE $TEMP_EN_CS_SNT_FILE > $TEMP_EN_CS_COOC_FILE \
) 2>&1 | awk '{ print ">>> [plain2snt.out]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running GIZA++ on training data."
( time $GIZA_PP -s $TEMP_EN_VCB_FILE -t $TEMP_CS_VCB_FILE \
  -c $TEMP_EN_CS_SNT_FILE -coocurrencefile $TEMP_EN_CS_COOC_FILE \
  -o en_cs -outputpath $CZENG_ALIGN_DIR -compactalignmentformat 1 \
) 2>&1 | awk '{ print ">>> [GIZA++]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
