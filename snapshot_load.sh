#!/bin/bash
set -e

MC=hnt_iot_helium-miner_1 # miner container name
ID_FILE=/tmp/.snapshot_load

trap "rm -f $ID_FILE" EXIT

fileName=$1
if [ ! -f "$fileName" ]; then
  echo "snapshot file $fileName not exist"
  exit 1
fi

function loading() {
  local s=`docker exec $MC ps`
  if [ $? -gt 0 ]; then
    echo "error $?"
    return 0
  fi
  local res=`echo $s | grep "snapshot load"`
  if [ -z "$res" ]; then
    echo "no"
  else
    echo "yes"
  fi
}

if test -f "$ID_FILE";then
  echo "in progress"
  exit 101
fi
if [ `loading` == "yes" ];then
  echo "load program running"
  exit 101
fi

printf "file=$fileName\ntime=`date +%s`" > $ID_FILE
echo "load snapshot $fileName"
sudo docker exec hnt_iot_helium-miner_1 miner snapshot load $fileName
