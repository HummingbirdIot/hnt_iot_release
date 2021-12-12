#!/bin/bash
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
  sudo rm -fr /tmp/snapshot-* >/dev/null 2>&1
#  docker exec ${dockerContainer} miner repair sync_resume
  docker exec ${dockerContainer} miner snapshot take $fileName
}


clean_miner() {
  echo "in clean miner"
  docker stop ${dockerContainer}
  sudo rm -fr /var/data/state_channel.db
  sudo rm -fr /var/data/ledger.db
  sudo rm -fr /var/data/blockchain.db
#  docker start ${dockerContainer}
}

apply_snapshot() {
  echo "in apply snapshot"
  docker start ${dockerContainer}

  docker exec ${dockerContainer} miner snapshot load $fileName
}


gen_snapshot && clean_miner && apply_snapshot
