#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)

TOOLS_DIR="$SCRIPT_DIR"/../Tools
SYMGIZA="$TOOLS_DIR"/symgiza-pp/src/symgiza
PLAIN2SNT="$TOOLS_DIR"/symgiza-pp/src/plain2snt
SNT2COOC="$TOOLS_DIR"/symgiza-pp/src/snt2cooc
MKCLS="$TOOLS_DIR"/symgiza-pp/src/mkcls/mkcls
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

  TEMP_CS_FILE="$TEMP_DIR"/"$czeng_file_base"_cs
  TEMP_CS_VCB_FILE="$TEMP_DIR"/"$czeng_file_base"_cs.vcb
  TEMP_CS_VCB_CLASSES_FILE="$TEMP_DIR"/"$czeng_file_base"_cs.vcb.classes
  TEMP_EN_FILE="$TEMP_DIR"/"$czeng_file_base"_en
  TEMP_EN_VCB_FILE="$TEMP_DIR"/"$czeng_file_base"_en.vcb
  TEMP_EN_VCB_CLASSES_FILE="$TEMP_DIR"/"$czeng_file_base"_en.vcb.classes
  TEMP_CS_EN_SNT_FILE="$TEMP_DIR"/"$czeng_file_base"_cs_"$czeng_file_base"_en.snt
  TEMP_EN_CS_SNT_FILE="$TEMP_DIR"/"$czeng_file_base"_en_"$czeng_file_base"_cs.snt
  TEMP_CS_EN_COOC_FILE="$TEMP_DIR"/"$czeng_file_base"_cs_"$czeng_file_base"_en.cooc
  TEMP_EN_CS_COOC_FILE="$TEMP_DIR"/"$czeng_file_base"_en_"$czeng_file_base"_cs.cooc

  CS_EN_PARAM_FILE="$CZENG_ALIGN_DIR"/cs_en.t1.5
  EN_CS_PARAM_FILE="$CZENG_ALIGN_DIR"/en_cs.t1.5
  ALL_PARAM_FILE="$CZENG_ALIGN_DIR"/all.param

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
( time $MKCLS -n2 -p$TEMP_CS_FILE -V$TEMP_CS_VCB_CLASSES_FILE \
) 2>&1 | awk '{ print ">>> [mkcls]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running mkcls on English training data."
( time $MKCLS -n2 -p$TEMP_EN_FILE -V$TEMP_EN_VCB_CLASSES_FILE \
) 2>&1 | awk '{ print ">>> [mkcls]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running plain2snt on training data."
( time $PLAIN2SNT $TEMP_EN_FILE $TEMP_CS_FILE \
) 2>&1 | awk '{ print ">>> [plain2snt]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running snt2cooc on training data."
( time $SNT2COOC $TEMP_CS_EN_COOC_FILE $TEMP_CS_VCB_FILE $TEMP_EN_VCB_FILE $TEMP_CS_EN_SNT_FILE \
) 2>&1 | awk '{ print ">>> [plain2snt]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running snt2cooc on English -> Czech training data."
( time $SNT2COOC $TEMP_EN_CS_COOC_FILE $TEMP_EN_VCB_FILE $TEMP_CS_VCB_FILE $TEMP_EN_CS_SNT_FILE \
) 2>&1 | awk '{ print ">>> [plain2snt]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Running SyMGIZA++ on training data."
( time $SYMGIZA -ncpus 4 -s $TEMP_EN_VCB_FILE -t $TEMP_CS_VCB_FILE \
  -cef $TEMP_EN_CS_SNT_FILE -cfe $TEMP_CS_EN_SNT_FILE \
  -CoocurrenceFileEF $TEMP_EN_CS_COOC_FILE -CoocurrenceFileFE $TEMP_CS_EN_COOC_FILE \
  -oef $CZENG_ALIGN_DIR/en_cs -ofe $CZENG_ALIGN_DIR/cs_en -o $CZENG_ALIGN_DIR/all \
  -m1 5 -m2 5 -m3 5 -m4 5 -mh 5 -t1 5 -t2 5 -t345 5 -th 5 \
  -m1symfrequency 5 -m2symfrequency 5 -m345symfrequency 5 -mhsymfrequency 5 \
  -tm 2 -es 1 -alig union -diagonal no -final no -both no \
  -emprobforempty 0.0 -probsmooth 1e-7 \
) 2>&1 | awk '{ print ">>> [SyMGIZA++]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Merging training parameters."
$MERGE_PARAM -s $TEMP_EN_VCB_FILE -t $TEMP_CS_VCB_FILE \
  -f $EN_CS_PARAM_FILE -r $CS_EN_PARAM_FILE -m 0.00001 -o $ALL_PARAM_FILE

echo ">>> [$SCRIPT][$(date)] Cleaning irrelevant output files."
rm $CZENG_ALIGN_DIR/all.trn.* $CZENG_ALIGN_DIR/all.tst.*
rm $CZENG_ALIGN_DIR/cs_en* $CZENG_ALIGN_DIR/en_cs*

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
