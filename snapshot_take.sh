#!/bin/bash

MC=hnt_iot_helium-miner_1 # miner container name
FILE_DIR=/tmp/
ID_FILE=$FILE_DIR.snapshot_take

# store file is like ini, eg time=1639537844
function getStoreValue() {
  if [ -f $ID_FILE ] && [ $1 == "time" ]; then
    awk -F "=" '/time/ {print $2}' $ID_FILE
  elif [ -f $ID_FILE ] && [ $1 == "file" ]; then
    awk -F "=" '/file/ {print $2}' $ID_FILE
  else
    echo ""
  fi
}

function isMinerRunning() {
  docker ps -a | grep $MC > /dev/null && echo yes || echo no
}

# generate snapshot file name in perticular format
function genFileName() {
  local h=`docker exec $MC miner info height | awk -F' ' '{print $2}'`
  if [ -z "$h" ]; then
    echo "error"
    return 1
  fi
  local f="/tmp/snapshot-${h}-`date +%s`"
  echo "$f"
}

function outputState() {
  local latestName=`ls /tmp/ | egrep "^snapshot-[0-9]{1,}-[0-9]{10}$" | tail -n 1`
  local latestFile="$FILE_DIR$latestName"
  if [ -n "$latestName" ]; then
    local time=`echo $latestName | cut -d- -f 3`
    echo ">>>state:time=$time,file=$latestFile,state=done"
    exit 0
  fi

  local currentFile=`getStoreValue file`
  local currentTime=`getStoreValue time`
  local got=`test -n "$currentTime" &&
    test -f "$currentFile" &&
    echo "done" || echo "pending"`
  echo ">>>state:time=$currentTime,file=$currentFile,state=$got"
}

function doSnapshot(){
  running=`isMinerRunning`
  if [ running == "no" ]; then
    echo "miner container is not running"
    exit 1
  fi

  fileName=`genFileName` &&
    printf "file=$fileName\ntime=`date +%s`" > $ID_FILE &&
    echo "to snapshot ..." &&
    sudo docker exec hnt_iot_helium-miner_1 miner snapshot take $fileName
}


case $1 in
  "state" ) outputState ;;
  "take" )  doSnapshot ;;
  * ) echo "error subcommand $1" && exit 1 ;;
esac