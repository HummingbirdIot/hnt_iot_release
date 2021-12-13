#!/bin/bash
idFile=/tmp/.snapshot_load_id

if test -f "$idFile";then
  echo "in progress"
  return 101
fi

touch $idFile
fileName=$1

echo "load snapshot" $fileName
sudo docker exec hnt_iot_helium-miner_1 miner snapshot load $fileName

rm -f $idFile
