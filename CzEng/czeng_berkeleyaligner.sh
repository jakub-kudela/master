#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)

TOOLS_DIR="$SCRIPT_DIR"/../Tools
BERKELEYALIGNER="$TOOLS_DIR"/berkeleyaligner/berkeleyaligner.jar
JVM_OPTS='-Xms1G -Xmx64G -server -ea'

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

  TEMP_DATA_DIR="$TEMP_DIR"/"$czeng_file_base"
  mkdir -p $TEMP_DATA_DIR

  TEMP_CS_FILE="$TEMP_DATA_DIR"/"$czeng_file_base".cs
  TEMP_EN_FILE="$TEMP_DATA_DIR"/"$czeng_file_base".en
  TEMP_CONF_FILE="$TEMP_DIR"/"$czeng_file_base".conf

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

function configurate() {

cat > $TEMP_CONF_FILE << EOL
##########################################
# Training: Defines the training regimen #
##########################################

forwardModels MODEL2 MODEL2
reverseModels MODEL2 MODEL2
mode JOINT JOINT
iters 5 5

###############################################
# Execution: Controls output and program flow #
###############################################

create
execDir $CZENG_ALIGN_DIR
overwriteExecDir true
saveParams true
alignTraining true
msPerLine 10000

#####################
# Performace tweaks #
#####################

numThreads 32
safeConcurrency true
cacheTreePath true
trainingCacheMaxSize 1000000

#################
# Language/Data #
#################

# Natural alignment order
# foreignSuffix cs
# englishSuffix en

# Reverse alignment order
foreignSuffix en
englishSuffix cs

# Training sources
trainSources $TEMP_DATA_DIR

# Testing sources
testSources $TEMP_DATA_DIR
maxTestSentences  0
offsetTestSentences 0

##############
# Evaluation #
##############

competitiveThresholding

EOL

}

# Script execution starts below:

echo ">>> [$SCRIPT][$(date)] Handling command line options."
handle_options "$@"

echo ">>> [$SCRIPT][$(date)] Starting execution in $PWD."
trap terminate EXIT TERM INT
cd $PWD

echo ">>> [$SCRIPT][$(date)] Preparing temporary folder."
prepare_temp

echo ">>> [$SCRIPT][$(date)] Preparing alignment confguration file."
configurate
  
echo ">>> [$SCRIPT][$(date)] Preparing training data."
cut -f 3 $CZENG_FILE > $TEMP_CS_FILE
cut -f 4 $CZENG_FILE > $TEMP_EN_FILE
  
echo ">>> [$SCRIPT][$(date)] Lowercasing training data."
perl -CSAD -pe '$_=lc' -i $TEMP_DATA_DIR/*

echo ">>> [$SCRIPT][$(date)] Running berkeleyaligner on training data."
( time java $JVM_OPTS -jar $BERKELEYALIGNER ++$TEMP_CONF_FILE \
) 2>&1 | awk '{ print ">>> [berkeleyaligner]["strftime()"] " $0; fflush(); }'

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
