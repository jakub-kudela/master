#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)

THREADS=5
URL_PREFIX=https://aws-publicdatasets.s3.amazonaws.com/
PATHS_URL_SUFFIX=common-crawl/crawl-data/CC-MAIN-2015-32/warc.paths.gz
WARC_FILE_FORMAT=%05d.warc.gz

# Script subroutines are listed below:

function handle_options() {
  
  while [ "$#" -gt 0 ]; do
    case $1 in
      -d|--hdfs_dir)
        HDFS_DIR="$2"
        shift;;
      *) ;;
    esac
    shift
  done

  if [ -z "$HDFS_DIR" ]; then
    echo ">>> [$SCRIPT][$(date)] ERROR: None or invalid d|--hdfs_dir option!"
    terminate
  fi

  echo ">>> [$SCRIPT][$(date)] Option d|--hdfs_dir = $HDFS_DIR."

}

function prepare_temp() {

  TEMP_DIR=$(mktemp -d "$SCRIPT""_XXXXX")

  PATHS_GZ_FILE="$TEMP_DIR"/warc.paths.gz
  PATHS_FILE="$TEMP_DIR"/warc.paths
  LS_FILE="$TEMP_DIR"/cc_download_ls

  echo ">>> [$SCRIPT][$(date)] Temporary folder is $TEMP_DIR."
  
}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
  rm -rf $LS_FILE $TEMP_DIR

  echo ">>> [$SCRIPT][$(date)] Script ended unsucessfully!"
  trap - EXIT TERM INT
  exit 1

}

function parallelize() {

  order=$1
  index=0

  while read path; do

    if [ $((++index % THREADS)) -ne $order ]; then continue; fi
    
    file=$(printf $WARC_FILE_FORMAT $index)
    if [ $(grep -c $file $LS_FILE) -ne 0 ]; then continue; fi

    url="$URL_PREFIX""$path"
    temp_path="$TEMP_DIR"/"$file"
    hdfs_path="$HDFS_DIR"/"$file"

    echo ">>> [$SCRIPT][$(date)] Downloading file $file locally."
    curl -s --fail -o $temp_path $url > /dev/null
    if [ $? -ne 0 ]; then
      echo ">>> [$SCRIPT][$(date)] ERROR: Failed to download file $file locally!"
      return 1
    fi

    echo ">>> [$SCRIPT][$(date)] Loading file $file into Hadoop."
    hadoop fs -copyFromLocal $temp_path $hdfs_path > /dev/null
    if [ $? -ne 0 ]; then
      echo ">>> [$SCRIPT][$(date)] ERROR: Failed to load file $file into Hadoop!"
      return 1
    fi

    echo ">>> [$SCRIPT][$(date)] Removing file $file locally."
    rm -f $temp_path

  done < $PATHS_FILE

}

# Script execution starts below:

echo ">>> [$SCRIPT][$(date)] Handling command line options."
handle_options "$@"

echo ">>> [$SCRIPT][$(date)] Starting execution in $PWD."
trap terminate EXIT TERM INT
cd $PWD

echo ">>> [$SCRIPT][$(date)] Preparing temporary folder."
prepare_temp

echo ">>> [$SCRIPT][$(date)] Downloading paths file."
paths_url="$URL_PREFIX""$PATHS_URL_SUFFIX"
curl -s --fail -o $PATHS_GZ_FILE $paths_url > /dev/null
if [ $? -ne 0 ]; then
  echo ">>> [$SCRIPT][$(date)] ERROR: Failed to download paths file!"
  terminate
fi

echo ">>> [$SCRIPT][$(date)] Extracting paths file."
gunzip -f $PATHS_GZ_FILE

echo ">>> [$SCRIPT][$(date)] Fetching already existing files."
hadoop fs -ls $HDFS_DIR | tail -n +2 | awk '{ print $8 }' > $LS_FILE
if [ $? -ne 0 ]; then
  echo ">>> [$SCRIPT][$(date)] ERROR: Failed to fetch already existing files!"
  terminate
fi

echo ">>> [$SCRIPT][$(date)] Preparing needed folders remotely."
hadoop fs -mkdir -p $HDFS_DIR
if [ $? -ne 0 ]; then
  echo ">>> [$SCRIPT][$(date)] ERROR: Failed to prepare needed folders remotely!"
  terminate
fi

count=$(wc -l < $PATHS_FILE)
echo ">>> [$SCRIPT][$(date)] About to process $count urls in $THREADS threads."
for ((i=0; i<$THREADS; i++)); do

  parallelize $i &

done
wait > /dev/null

echo ">>> [$SCRIPT][$(date)] Refetching already existing files."
hadoop fs -ls $HDFS_DIR | tail -n +2 | awk '{ print $8 }' > $LS_FILE
if [ $? -ne 0 ]; then
  echo ">>> [$SCRIPT][$(date)] ERROR: Failed to refetch already existing files!"
  terminate
fi

echo ">>> [$SCRIPT][$(date)] Validating count of downloaded files."
files_count=$(wc -l < $LS_FILE)
paths_count=$(wc -l < $PATHS_FILE)
if [ $files_count -ne $paths_count ]; then
  echo ">>> [$SCRIPT][$(date)] ERROR: Invalid count of download files!"
  terminate
fi

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $LS_FILE $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
