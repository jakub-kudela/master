#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)
TOOLS_DIR="$SCRIPT_DIR"

CZENG_TOKEN_ON=0
CZENG_LEMMA_ON=0
CC_TOKEN_ON=0
CC_LEMMA_ON=0

PREPARE_CZENG="$SCRIPT_DIR"/prepare_czeng.sh
PREPARE_CC="$SCRIPT_DIR"/prepare_cc.sh
CREATE_DOCVEC="$SCRIPT_DIR"/create_docvec.py
ALIGN_DOCVEC="$SCRIPT_DIR"/align_docvec.py
BENCH_ALIGN="$SCRIPT_DIR"/bench_align.py
SCORE_ALIGN="$SCRIPT_DIR"/score_align.py
TRAIN_CLASSIFIER="$SCRIPT_DIR"/train_network.py
APPLY_CLASSIFIER="$SCRIPT_DIR"/apply_network.py
DUMP_ALIGN="$SCRIPT_DIR"/dump_align.py

CZENG_DATA_DIR=../CzEngData
CZENG_TOKEN_HEAD_FILE="$CZENG_DATA_DIR"/czeng_token_head
CZENG_TOKEN_TAIL_FILE="$CZENG_DATA_DIR"/czeng_token_tail
CZENG_TOKEN_WORDVEC_CS_FILE="$CZENG_DATA_DIR"/czeng_token_head_bivec/wordvec.cs
CZENG_TOKEN_WORDVEC_EN_FILE="$CZENG_DATA_DIR"/czeng_token_head_bivec/wordvec.en
CZENG_TOKEN_WEIGHT_FILE="$CZENG_DATA_DIR"/czeng_token_head_giza/all.param
CZENG_LEMMA_HEAD_FILE="$CZENG_DATA_DIR"/czeng_lemma_head
CZENG_LEMMA_TAIL_FILE="$CZENG_DATA_DIR"/czeng_lemma_tail
CZENG_LEMMA_WORDVEC_CS_FILE="$CZENG_DATA_DIR"/czeng_lemma_head_bivec/wordvec.cs
CZENG_LEMMA_WORDVEC_EN_FILE="$CZENG_DATA_DIR"/czeng_lemma_head_bivec/wordvec.en
CZENG_LEMMA_WEIGHT_FILE="$CZENG_DATA_DIR"/czeng_lemma_head_giza/all.param

CC_DATA_DIR=../CommonCrawlData
CC_TOKEN_FILE="$CC_DATA_DIR"/cc_token
CC_LEMMA_FILE="$CC_DATA_DIR"/cc_lemma

# Script subroutines are listed below:

function handle_options() {
  
  while [ "$#" -gt 0 ]; do
    case $1 in
      -czt|--czeng_token)
        CZENG_TOKEN_ON=1;;
      -czl|--czeng_lemma)
        CZENG_LEMMA_ON=1;;
      -cct|--cc_token)
        CC_TOKEN_ON=1;;
      -ccl|--cc_lemma)
        CC_LEMMA_ON=1;;
      *) ;;
    esac
    shift
  done

  echo ">>> [$SCRIPT][$(date)] Option -czt|--czeng_token = $CZENG_TOKEN_ON."
  echo ">>> [$SCRIPT][$(date)] Option -czl|--czeng_lemma) = $CZENG_LEMMA_ON."
  echo ">>> [$SCRIPT][$(date)] Option -cct|--cc_token = $CC_TOKEN_ON."
  echo ">>> [$SCRIPT][$(date)] Option -ccl|--cc_lemma = $CC_LEMMA_ON."
  
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

if [ $CZENG_TOKEN_ON -eq 1 ]; then
  # NOTE: Processing tokenized CzEng head.
  execute $PREPARE_CZENG -c $CZENG_TOKEN_HEAD_FILE -cs czeng_token_head_doc_cs -en czeng_token_head_doc_en -b 50000
  execute $CREATE_DOCVEC -d czeng_token_head_doc_cs -w $CZENG_TOKEN_WORDVEC_CS_FILE -o czeng_token_head_docvec_cs
  execute $CREATE_DOCVEC -d czeng_token_head_doc_en -w $CZENG_TOKEN_WORDVEC_EN_FILE -o czeng_token_head_docvec_en

  execute $ALIGN_DOCVEC -s czeng_token_head_docvec_cs -t czeng_token_head_docvec_en -o czeng_token_head_align -n 20
  execute $BENCH_ALIGN -a czeng_token_head_align -t czeng_token_head_doc_en -o czeng_token_head_align_bench

  execute $SCORE_ALIGN -a czeng_token_head_align -s czeng_token_head_doc_cs -t czeng_token_head_doc_en -m 1.08 -d 0.28 -w $CZENG_TOKEN_WEIGHT_FILE -o czeng_token_head_score
  execute $BENCH_ALIGN -a czeng_token_head_score -t czeng_token_head_doc_en -o czeng_token_head_score_bench

  execute $TRAIN_CLASSIFIER -a czeng_token_head_score -s czeng_token_head_doc_cs -t czeng_token_head_doc_en -m 1.08 -d 0.28 -w $CZENG_TOKEN_WEIGHT_FILE -o czeng_token_head_classifier

  # NOTE: Processing tokenized CzEng tail.
  execute $PREPARE_CZENG -c $CZENG_TOKEN_TAIL_FILE -cs czeng_token_tail_doc_cs -en czeng_token_tail_doc_en -b 50000
  execute $CREATE_DOCVEC -d czeng_token_tail_doc_cs -w $CZENG_TOKEN_WORDVEC_CS_FILE -o czeng_token_tail_docvec_cs
  execute $CREATE_DOCVEC -d czeng_token_tail_doc_en -w $CZENG_TOKEN_WORDVEC_EN_FILE -o czeng_token_tail_docvec_en

  execute $ALIGN_DOCVEC -s czeng_token_tail_docvec_cs -t czeng_token_tail_docvec_en -o czeng_token_tail_align -n 20
  execute $BENCH_ALIGN -a czeng_token_tail_align -t czeng_token_tail_doc_en -o czeng_token_tail_align_bench

  execute $SCORE_ALIGN -a czeng_token_tail_align -s czeng_token_tail_doc_cs -t czeng_token_tail_doc_en -m 1.08 -d 0.28 -w $CZENG_TOKEN_WEIGHT_FILE -o czeng_token_tail_score
  execute $BENCH_ALIGN -a czeng_token_tail_score -t czeng_token_tail_doc_en -o czeng_token_tail_score_bench

  execute $APPLY_CLASSIFIER -a czeng_token_tail_score -s czeng_token_tail_doc_cs -t czeng_token_tail_doc_en -m 1.08 -d 0.28 -w $CZENG_TOKEN_WEIGHT_FILE -c czeng_token_head_classifier -f 0.50 -o czeng_token_tail_class
  execute $DUMP_ALIGN -a czeng_token_tail_class -s czeng_token_head_doc_cs -t czeng_token_head_doc_en -o czeng_token_tail_class_dump -d
  execute $BENCH_ALIGN -a czeng_token_tail_class -t czeng_token_tail_doc_en -o czeng_token_tail_class_bench
fi

if [ $CZENG_LEMMA_ON -eq 1 ]; then
  # NOTE: Processing lemmatized CzEng head.
  execute $PREPARE_CZENG -c $CZENG_LEMMA_HEAD_FILE -cs czeng_lemma_head_doc_cs -en czeng_lemma_head_doc_en -b 50000
  execute $CREATE_DOCVEC -d czeng_lemma_head_doc_cs -w $CZENG_LEMMA_WORDVEC_CS_FILE -o czeng_lemma_head_docvec_cs
  execute $CREATE_DOCVEC -d czeng_lemma_head_doc_en -w $CZENG_LEMMA_WORDVEC_EN_FILE -o czeng_lemma_head_docvec_en

  execute $ALIGN_DOCVEC -s czeng_lemma_head_docvec_cs -t czeng_lemma_head_docvec_en -o czeng_lemma_head_align -n 20
  execute $BENCH_ALIGN -a czeng_lemma_head_align -t czeng_lemma_head_doc_en -o czeng_lemma_head_align_bench

  execute $SCORE_ALIGN -a czeng_lemma_head_align -s czeng_lemma_head_doc_cs -t czeng_lemma_head_doc_en -m 1.08 -d 0.28 -w $CZENG_LEMMA_WEIGHT_FILE -o czeng_lemma_head_score
  execute $BENCH_ALIGN -a czeng_lemma_head_score -t czeng_lemma_head_doc_en -o czeng_lemma_head_score_bench

  execute $TRAIN_CLASSIFIER -a czeng_lemma_head_score -s czeng_lemma_head_doc_cs -t czeng_lemma_head_doc_en -m 1.08 -d 0.28 -w $CZENG_LEMMA_WEIGHT_FILE -o czeng_lemma_head_classifier

  # NOTE: Processing lemmatized CzEng head.
  execute $PREPARE_CZENG -c $CZENG_LEMMA_TAIL_FILE -cs czeng_lemma_tail_doc_cs -en czeng_lemma_tail_doc_en -b 50000
  execute $CREATE_DOCVEC -d czeng_lemma_tail_doc_cs -w $CZENG_LEMMA_WORDVEC_CS_FILE -o czeng_lemma_tail_docvec_cs
  execute $CREATE_DOCVEC -d czeng_lemma_tail_doc_en -w $CZENG_LEMMA_WORDVEC_EN_FILE -o czeng_lemma_tail_docvec_en

  execute $ALIGN_DOCVEC -s czeng_lemma_tail_docvec_cs -t czeng_lemma_tail_docvec_en -o czeng_lemma_tail_align -n 20
  execute $BENCH_ALIGN -a czeng_lemma_tail_align -t czeng_lemma_tail_doc_en -o czeng_lemma_tail_align_bench

  execute $SCORE_ALIGN -a czeng_lemma_tail_align -s czeng_lemma_tail_doc_cs -t czeng_lemma_tail_doc_en -m 1.08 -d 0.28 -w $CZENG_LEMMA_WEIGHT_FILE -o czeng_lemma_tail_score
  execute $BENCH_ALIGN -a czeng_lemma_tail_score -t czeng_lemma_tail_doc_en -o czeng_lemma_tail_score_bench

  execute $APPLY_CLASSIFIER -a czeng_lemma_tail_score -s czeng_lemma_tail_doc_cs -t czeng_lemma_tail_doc_en -m 1.08 -d 0.28 -w $CZENG_LEMMA_WEIGHT_FILE -c czeng_lemma_head_classifier -f 0.50 -o czeng_lemma_tail_class
  execute $DUMP_ALIGN -a czeng_lemma_tail_class -s czeng_lemma_head_doc_cs -t czeng_lemma_head_doc_en -o czeng_lemma_tail_class_dump -d
  execute $BENCH_ALIGN -a czeng_lemma_tail_class -t czeng_lemma_tail_doc_en -o czeng_lemma_tail_class_bench
fi

if [ $CC_TOKEN_ON -eq 1 ]; then
  # NOTE: Processing tokenized CommonCrawl.
  execute $PREPARE_CC -c $CC_TOKEN_FILE -cs cc_token_doc_cs -en cc_token_doc_en
  execute $CREATE_DOCVEC -d cc_token_doc_cs -w $CZENG_TOKEN_WORDVEC_CS_FILE -o cc_token_docvec_cs
  execute $CREATE_DOCVEC -d cc_token_doc_en -w $CZENG_TOKEN_WORDVEC_EN_FILE -o cc_token_docvec_en

  execute $ALIGN_DOCVEC -s cc_token_docvec_cs -t cc_token_docvec_en -o cc_token_align
  execute $SCORE_ALIGN -a cc_token_align -s cc_token_doc_cs -t cc_token_doc_en -m 1.08 -d 0.28 -w $CZENG_TOKEN_WEIGHT_FILE -o cc_token_score
  execute $APPLY_CLASSIFIER -a cc_token_score -s cc_token_doc_cs -t cc_token_doc_en -m 1.08 -d 0.28 -w $CZENG_TOKEN_WEIGHT_FILE -c czeng_token_head_classifier -f 0.99  -o cc_token_class
  execute $DUMP_ALIGN -a cc_token_class -s cc_token_doc_cs -t cc_token_doc_en -o cc_token_class_dump
fi

if [ $CC_LEMMA_ON -eq 1 ]; then
  # NOTE: Processing lemmatized CommonCrawl.
  execute $PREPARE_CC -c $CC_LEMMA_FILE -cs cc_lemma_doc_cs -en cc_lemma_doc_en
  execute $CREATE_DOCVEC -d cc_lemma_doc_cs -w $CZENG_LEMMA_WORDVEC_CS_FILE -o cc_lemma_docvec_cs
  execute $CREATE_DOCVEC -d cc_lemma_doc_en -w $CZENG_LEMMA_WORDVEC_EN_FILE -o cc_lemma_docvec_en

  execute $ALIGN_DOCVEC -s cc_lemma_docvec_cs -t cc_lemma_docvec_en -o cc_lemma_align
  execute $SCORE_ALIGN -a cc_lemma_align -s cc_lemma_doc_cs -t cc_lemma_doc_en -m 1.08 -d 0.28 -w $CZENG_LEMMA_WEIGHT_FILE -o cc_lemma_score
  execute $APPLY_CLASSIFIER -a cc_lemma_score -s cc_lemma_doc_cs -t cc_lemma_doc_en -m 1.08 -d 0.28 -w $CZENG_LEMMA_WEIGHT_FILE -c czeng_lemma_head_classifier -f 0.99  -o cc_lemma_class
  execute $DUMP_ALIGN -a cc_lemma_class -s cc_lemma_doc_cs -t cc_lemma_doc_en -o cc_lemma_class_dump
fi

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
