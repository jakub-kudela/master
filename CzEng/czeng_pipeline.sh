#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)
TOOLS_DIR="$SCRIPT_DIR"

CZENG_DOWNLOAD="$SCRIPT_DIR"/czeng_download.sh
CZENG_TOKENIZE="$SCRIPT_DIR"/czeng_tokenize.sh
CZENG_LEMMATIZE="$SCRIPT_DIR"/czeng_lemmatize.sh
CZENG_SPLIT="$SCRIPT_DIR"/czeng_split.sh
CZENG_CLEAN="$SCRIPT_DIR"/czeng_clean.py
CZENG_GIZA="$SCRIPT_DIR"/czeng_symgiza.sh
CZENG_BIVEC="$SCRIPT_DIR"/czeng_bivec.sh

CZENG_DOWNLOAD_ON=0
CZENG_TOKENIZE_ON=0
CZENG_LEMMATIZE_ON=0
CZENG_SPLIT_ON=0
CZENG_CLEAN_ON=0
CZENG_GIZA_ON=0
CZENG_BIVEC_ON=0

CZENG_FILE=czeng
CZENG_TOKEN_FILE=czeng_token
CZENG_TOKEN_HEAD_FILE=czeng_token_head
CZENG_TOKEN_HEAD_GIZA_DIR=czeng_token_head_giza
CZENG_TOKEN_HEAD_BIVEC_DIR=czeng_token_head_bivec
CZENG_TOKEN_TAIL_FILE=czeng_token_tail
CZENG_LEMMA_FILE=czeng_lemma
CZENG_LEMMA_HEAD_FILE=czeng_lemma_head
CZENG_LEMMA_HEAD_GIZA_DIR=czeng_lemma_head_giza
CZENG_LEMMA_HEAD_BIVEC_DIR=czeng_lemma_head_bivec
CZENG_LEMMA_TAIL_FILE=czeng_lemma_tail

# Script subroutines are listed below:

function handle_options() {
  
  while [ "$#" -gt 0 ]; do
    case $1 in
      -d|--download)
        CZENG_DOWNLOAD_ON=1;;
      -t|--tokenize)
        CZENG_TOKENIZE_ON=1;;
      -l|--lemmatize)
        CZENG_LEMMATIZE_ON=1;;
      -s|--split)
        CZENG_SPLIT_ON=1;;
      -c|--clean)
        CZENG_CLEAN_ON=1;;
      -g|--giza)
        CZENG_GIZA_ON=1;;
      -b|--bivec)
        CZENG_BIVEC_ON=1;;
      *) ;;
    esac
    shift
  done

  echo ">>> [$SCRIPT][$(date)] Option -d|--download = $CZENG_DOWNLOAD_ON."
  echo ">>> [$SCRIPT][$(date)] Option -t|--tokenize = $CZENG_TOKENIZE_ON."
  echo ">>> [$SCRIPT][$(date)] Option -l|--lemmatize = $CZENG_LEMMATIZE_ON."
  echo ">>> [$SCRIPT][$(date)] Option -s|--split = $CZENG_SPLIT_ON."
  echo ">>> [$SCRIPT][$(date)] Option -c|--clean = $CZENG_CLEAN_ON."
  echo ">>> [$SCRIPT][$(date)] Option -g|--giza = $CZENG_GIZA_ON."
  echo ">>> [$SCRIPT][$(date)] Option -b|--bivec = $CZENG_BIVEC_ON."
  
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

if [ $CZENG_DOWNLOAD_ON -eq 1 ]; then
  execute $CZENG_DOWNLOAD -c $CZENG_FILE
fi

if [ $CZENG_TOKENIZE_ON -eq 1 ]; then 
  execute $CZENG_TOKENIZE -c $CZENG_FILE -t $CZENG_TOKEN_FILE
fi

if [ $CZENG_LEMMATIZE_ON -eq 1 ]; then
  execute $CZENG_LEMMATIZE -c $CZENG_FILE -l $CZENG_LEMMA_FILE
fi

if [ $CZENG_SPLIT_ON -eq 1 ]; then 
  execute $CZENG_SPLIT -c $CZENG_TOKEN_FILE -h $CZENG_TOKEN_HEAD_FILE -t $CZENG_TOKEN_TAIL_FILE -r 50
  execute $CZENG_SPLIT -c $CZENG_LEMMA_FILE -h $CZENG_LEMMA_HEAD_FILE -t $CZENG_LEMMA_TAIL_FILE -r 50
fi

if [ $CZENG_CLEAN_ON -eq 1 ]; then
  execute $CZENG_CLEAN -c $CZENG_TOKEN_HEAD_FILE -m 1 -x 50
  execute $CZENG_CLEAN -c $CZENG_LEMMA_HEAD_FILE -m 1 -x 50

  execute $CZENG_CLEAN -c $CZENG_TOKEN_TAIL_FILE -m 1 -x 10000
  execute $CZENG_CLEAN -c $CZENG_LEMMA_TAIL_FILE -m 1 -x 10000
fi

if [ $CZENG_GIZA_ON -eq 1 ]; then
  execute $CZENG_GIZA -c $CZENG_TOKEN_HEAD_FILE -a $CZENG_TOKEN_HEAD_GIZA_DIR
  execute $CZENG_GIZA -c $CZENG_LEMMA_HEAD_FILE -a $CZENG_LEMMA_HEAD_GIZA_DIR
fi

if [ $CZENG_BIVEC_ON -eq 1 ]; then
  czeng_token_head_align_file="$CZENG_TOKEN_HEAD_GIZA_DIR"/all.A3.final_symal
  czeng_lemma_head_align_file="$CZENG_LEMMA_HEAD_GIZA_DIR"/all.A3.final_symal

  execute $CZENG_BIVEC -c $czeng_token_head_align_file -b $CZENG_TOKEN_HEAD_BIVEC_DIR
  execute $CZENG_BIVEC -c $czeng_lemma_head_align_file -b $CZENG_LEMMA_HEAD_BIVEC_DIR
fi

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
