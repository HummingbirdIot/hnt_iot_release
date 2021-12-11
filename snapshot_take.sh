#!/bin/bash
idFile=/tmp/.snapshot_take_id

if test -f "$idFile";then
  echo "in progress"
  return 127
fi

touch $idFile
height=`docker exec hnt_iot_helium-miner_1 miner info height | awk -F' ' '{print $2}'`
fileName="/tmp/snapshot-${height}"

function snapshotIsDone() {
  local size=`wc -c "$fileName" | awk '{print $1}'`

  local i=0
  while [ $i -le 120 ]
  do
    sleep 1
    ((i++))
    local sizeNew=`wc -c "$fileName" | awk '{print $1}'`
    if [ $size == $sizeNew ];
    then
      return 0
    fi
  done
  echo "wait snapshot timeout"
}


echo $fileName
if test -f "$fileName";then
  echo "progress already exist"
else
  echo "taking snapshot " $fileName
  sudo docker exec hnt_iot_helium-miner_1 miner snapshot take $fileName
fi

snapshotIsDone

echo ">>>filepath: ${fileName}"
rm -f $idFile
