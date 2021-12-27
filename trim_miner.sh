#!/bin/bash
source "$(dirname "$0")/util.sh"

dockerContainer="hnt_iot_helium-miner_1"
height=`docker exec hnt_iot_helium-miner_1 miner info height | awk -F' ' '{print $2}'`
fileName="/tmp/snapshot-${height}"

check_miner_exist() {
  docker ps | grep ${dockerContainer}
  if [ $? -eq 0 ]; then
    return 0
  fi
  echo "not exist"
  #docker start ${dockerContainer}
  sleep 60
}

gen_snapshot() {
  echo "genenate snapshot"
#  docker exec ${dockerContainer} miner repair sync_resume
  if [ -f "$fileName" ]; then
    echo "generated snapshot: " $fileName
    return 0
  fi
  docker exec ${dockerContainer} miner snapshot take $fileName

  sleep 5
  if [ -f "$fileName" ]; then
    echo "generated snapshot: " $fileName
    return 0
  fi
  return 1
}


clean_miner() {
  echo "in clean miner"
  docker stop ${dockerContainer}
  sudo rm -fr /var/data/state_channel.db
  sudo rm -fr /var/data/ledger.db
  sudo rm -fr /var/data/blockchain.db
}

apply_snapshot() {
  echo "in apply snapshot: " $fileName
  docker start ${dockerContainer}
  sleep 30
  docker exec ${dockerContainer} miner snapshot load $fileName
}


# do clean stuff
sudo rm -fr /tmp/snapshot-* >/dev/null 2>&1
sudo rm -fr /var/data/snap/snap*

if [ "$1" == "createSnap" ]; then
  gen_snapshot
  clean_miner
  apply_snapshot
else
  clean_miner
  docker start ${dockerContainer}
fi
