#!/bin/bash
dockerContainer="hnt_iot_helium-miner_1"
otaDir="/var/for_ota"
snapshotName=`date "+snap-%Y-%m-%d"`
snapshotSrcPath="/var/data/snap/${snapshotName}"
snapshotSrcHostPath="/var/data/snap/${snapshotName}"
snapshotOtaPath="${otaDir}/${snapshotName}"

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
  mkdir -p ${otaDir}
  sudo rm -fr /var/data/snap/*
  docker exec ${dockerContainer} miner repair sync_resume
  docker exec ${dockerContainer} miner snapshot take ${snapshotSrcPath}
  sudo mv ${snapshotSrcHostPath} ${otaDir}
}


clean_miner() {
  echo "in clean miner"
  docker stop ${dockerContainer}
  sudo rm -fr /var/data/state_channel.db
  sudo rm -fr /var/data/ledger.db
  sudo rm -fr /var/data/blockchain.db
  docker start ${dockerContainer}
}

apply_snapshot() {
  echo "in apply stop"
  docker stop ${dockerContainer}

  sudo cp ${snapshotOtaPath} ${snapshotSrcHostPath}
  docker start ${dockerContainer}
  docker exec ${dockerContainer} miner snapshot load ${snapshotSrcPath}
}


clean_miner
