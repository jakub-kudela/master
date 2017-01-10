#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)
TOOLS_DIR="$SCRIPT_DIR"

CC_TOKENIZE="$SCRIPT_DIR"/cc_tokenize.sh
CC_LEMMATIZE="$SCRIPT_DIR"/cc_lemmatize.sh

CC_TOKENIZE_ON=0
CC_LEMMATIZE_ON=0

CC_FILE=cc
CC_TOKEN_FILE=cc_token
CC_LEMMA_FILE=cc_lemma

# Script subroutines are listed below:

function handle_options() {
  
  while [ "$#" -gt 0 ]; do
    case $1 in
      -t|--tokenize)
        CC_TOKENIZE_ON=1;;
      -l|--lemmatize)
        CC_LEMMATIZE_ON=1;;
      *) ;;
    esac
    shift
  done

  echo ">>> [$SCRIPT][$(date)] Option -t|--tokenize = $CC_TOKENIZE_ON."
  echo ">>> [$SCRIPT][$(date)] Option -l|--lemmatize = $CC_LEMMATIZE_ON."
  
}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Script ended unsucessfully!"
  trap - EXIT TERM INT
  exit 1

}

function execute() { 

  echo ">>> [$SCRIPT][$(date)] $@."
  "$@" 

}

# Script execution starts below:

echo ">>> [$SCRIPT][$(date)] Handling command line options."
handle_options "$@"

echo ">>> [$SCRIPT][$(date)] Starting execution in $PWD."
trap terminate EXIT TERM INT
cd $PWD

if [ $CC_TOKENIZE_ON -eq 1 ]; then 
  execute $CC_TOKENIZE -c $CC_FILE -t $CC_TOKEN_FILE
fi

if [ $CC_LEMMATIZE_ON -eq 1 ]; then
  execute $CC_LEMMATIZE -c $CC_FILE -l $CC_LEMMA_FILE
fi

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
