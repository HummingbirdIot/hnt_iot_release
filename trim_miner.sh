#!/bin/bash
source "$(dirname "$0")/util.sh"
source "$(dirname "$0")/const.sh"

MC="$CONTAINER_MINER"
height=`docker exec ${MC} miner info height | awk -F' ' '{print $2}'`
fileName="/tmp/snapshot-${height}"

check_miner_exist() {
  docker ps | grep ${MC}
  if [ $? -eq 0 ]; then
    return 0
  fi
  echo "not exist"
  #docker start ${MC}
  sleep 60
}

gen_snapshot() {
  echo "genenate snapshot"
#  docker exec ${MC} miner repair sync_resume
  if [ -f "$fileName" ]; then
    echo "generated snapshot: " $fileName
    return 0
  fi
  docker exec ${MC} miner snapshot take $fileName

  sleep 5
  if [ -f "$fileName" ]; then
    echo "generated snapshot: " $fileName
    return 0
  fi
  return 1
}


clean_miner() {
  echo "in clean miner"
  docker stop ${MC}
  sudo rm -fr /var/data/state_channel.db
  sudo rm -fr /var/data/ledger.db
  sudo rm -fr /var/data/blockchain.db
}

apply_snapshot() {
  echo "in apply snapshot: " $fileName
  docker start ${MC}
  sleep 30
  docker exec ${MC} miner snapshot load $fileName
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
  docker start ${MC}
fi
