#!/bin/bash

# Script constants are listed below:

PWD=$(pwd)
SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)
ORIGINAL_STTY=$(stty -g 2> /dev/null)

URL_FORMAT=http://ufallab.ms.mff.cuni.cz/~bojar/czeng10-data/data-plaintext-format.%d.tar
PASSWORD=czeng
MIN_INDEX=0
MAX_INDEX=9
THREADS=5

# Script subroutines are listed below:

function handle_options() {
  
  while [ "$#" -gt 0 ]; do
    case $1 in
      -c|--czeng)
        CZENG_FILE="$2"
        shift;;
      *) ;;
    esac
    shift
  done

  if [ -z "$CZENG_FILE" ]; then
  	echo ">>> [$SCRIPT][$(date)] ERROR: Invalid -c|--czeng option!"
  	exit 1
  fi
 
  echo ">>> [$SCRIPT][$(date)] Option -c|--czeng = $CZENG_FILE."

}

function prepare_temp() {

  TEMP_DIR=$(mktemp -d "$SCRIPT""_XXXXX")

  echo ">>> [$SCRIPT][$(date)] Temporary folder is $TEMP_DIR."
  
}

function terminate() {

  echo ">>> [$SCRIPT][$(date)] Killing process tree."
  jobs -p | xargs --no-run-if-empty kill -9

  echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
  rm -rf $TEMP_DIR 

  echo ">>> [$SCRIPT][$(date)] Cleaning erroneous output."
  rm -rf $CZENG_FILE

  echo ">>> [$SCRIPT][$(date)] Restoring environment settings."
  stty $ORIGINAL_STTY > /dev/null 2>&1

  echo ">>> [$SCRIPT][$(date)] Script $SCRIPT ended unsucessfully!"
  trap - EXIT TERM INT
  exit 1

}

function parallelize() {

  order=$1

  for ((index=$MIN_INDEX; index<=$MAX_INDEX; index++)); do
    
    if [ $((index % THREADS)) -ne $order ]; then continue; fi

    url=$(printf $URL_FORMAT $index)
    file=$(basename $url)
    file_path="$TEMP_DIR/$file"
    credentials="$username:$PASSWORD"

    echo ">>> [$SCRIPT][$(date)] Downloading file $file."
    curl -s --fail -u $credentials -o $file_path $url > /dev/null
    if [ $? -ne 0 ]; then
      echo ">>> [$SCRIPT][$(date)] ERROR: Failed to download file $file!"
      return 1
    fi

  done

}

# Script execution starts below:

echo ">>> [$SCRIPT][$(date)] Handling command line options."
handle_options "$@"

echo ">>> [$SCRIPT][$(date)] Starting execution in $PWD."
trap terminate EXIT TERM INT
cd $PWD

echo ">>> [$SCRIPT][$(date)] Preparing temporary folder."
prepare_temp

echo ">>> [$SCRIPT][$(date)] Requesting CzEng registration username."
read -s -p "" username

count=$((MAX_INDEX - MIN_INDEX + 1))
echo ">>> [$SCRIPT][$(date)] About to process $count urls in $THREADS threads."
for ((i=0; i<$THREADS; i++)); do

  parallelize $i &

done
wait > /dev/null

echo ">>> [$SCRIPT][$(date)] Validating count of downloaded files."
files_count=$(ls $TEMP_DIR | wc -l)
paths_count=$((MAX_INDEX - MIN_INDEX + 1))
if [ $files_count -ne $paths_count ]; then
  echo ">>> [$SCRIPT][$(date)] ERROR: Invalid count of download files!"
  terminate
fi

for tar_file in $(find $TEMP_DIR -name "*.tar"); do 
  echo ">>> [$SCRIPT][$(date)] Extracting tar file $tar_file."
  tar -xvf $tar_file -C $TEMP_DIR > /dev/null
  rm -f $tar_file
done

for gz_file in $(find $TEMP_DIR -name "*.gz"); do 
  echo ">>> [$SCRIPT][$(date)] Extracting gz file $gz_file."
  gunzip $gz_file > /dev/null
done

rm -f $CZENG_FILE
for part_file in $(find $TEMP_DIR -type f); do 
  echo ">>> [$SCRIPT][$(date)] Collecting CzEng file $part_file."
  cat $part_file >> $CZENG_FILE
  rm -f $part_file
done

echo ">>> [$SCRIPT][$(date)] Cleaning temporary files."
rm -rf $TEMP_DIR

echo ">>> [$SCRIPT][$(date)] Script ended successfully."
trap - EXIT TERM INT
exit 0
