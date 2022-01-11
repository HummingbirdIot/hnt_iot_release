#!/bin/bash
set -x
source "$(dirname "$0")/const.sh"

VERSION=0.8
SELF_NAME=`basename "$0"`

function retry()
{
  local n=0
  local try=$1
  local cmd="${@: 2}"
  [[ $# -le 1 ]] && {
    echo "Usage $0 <retry_number> <Command>"; }

  until [[ $n -ge $try ]]
  do
    $cmd && break || {
      echo "Command Fail.."
          ((n++))
          echo "retry $n ::"
          sleep 1;
        }

  done
}

function tryWaitNetwork() {
  tryNum=1
  while [ $tryNum -le 20 ]
  do
    ping -q -w 1 -c 1  `ip r | grep default | cut -d ' ' -f 3 | head -n 1` > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      return 0
    fi
    tryNum=$(( $tryNum + 1 ))
  done
  return -1
}

function freeDiskPressure() {
  usage=`df -h |grep '/dev/root' | awk '{print $5}' | tr -dc '0-9'`
  if ((usage > 80)); then
    echo "trim miner"
    sudo bash ./trim_miner.sh createSnap
  fi
}

function gitSetup() {
  git config user.email "hummingbirdiot@example.com"
  git config user.name "hummingbirdiot"
}

function checkPublicKeyfile() {
  sudo touch /var/data/public_keys
}

function updateReleaseVersion() {
  diff ./config/lsb_release /etc/lsb_release >/dev/null 2>&1
  if [ $? -ne 0 ];then
    sudo cp ./config/lsb_release /etc/lsb_release
  fi
}

function patchDhcpcd() {
  diff ./config/patch/wait.conf /etc/systemd/system/dhcpcd.service.d/wait.conf > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "patching dhcpcd"
    sudo cp ./config/patch/wait.conf /etc/systemd/system/dhcpcd.service.d/wait.conf
    sync
    sudo systemctl daemon-reload
    sudo systemctl restart dhcpcd
  fi
}

function patchHiotTimer() {
  diff ./config/patch/hiot.timer /etc/systemd/system/hiot.timer > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "patching hiot timer"
    sudo cp ./config/patch/hiot.timer /etc/systemd/system/hiot.timer
    sync
    sudo systemctl daemon-reload
    sudo systemctl restart hiot.timer
  fi
}

function setupDbus() {
  should_restart_dbus=false
  diff ./config/com.helium.Miner.conf /etc/dbus-1/system.d/com.helium.Miner.conf >/dev/null 2>&1
  if [ $? -ne 0 ];then
    sudo cp ./config/com.helium.Miner.conf /etc/dbus-1/system.d/com.helium.Miner.conf
    should_restart_dbus=true
  fi
  diff ./config/com.helium.Config.conf /etc/dbus-1/system.d/com.helium.Config.conf >/dev/null 2>&1
  if [ $? -ne 0 ];then
    sudo cp ./config/com.helium.Config.conf /etc/dbus-1/system.d/com.helium.Config.conf
    should_restart_dbus=true
    #sudo systemctl restart dbus
  fi
  if [ "$should_restart_dbus" = true ]; then
    echo "restart dbus"
    sync
    sudo systemctl restart dbus
  fi
}

function startHummingbird() {
  echo "Start hummingbird "
  local n=0
  local try=3

  until [[ $n -ge $try ]]
  do
    docker-compose up -d
    if [ $? -eq 0 ]; then
      return 0
    else
      sleep 1
      ((n++))
    fi
  done

  ## still failed try prune then
  ping -q -w 1 -c 1  8.8.8.8 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    docker-compose down
    #sudo docker system prune -a -f
    sudo docker images -a | grep "miner-arm64" | awk '{print $3}' | xargs docker rmi
    retry 3 docker-compose up -d
  else
    echo "no network access???"
  fi
}

function stopHummingbirdMiner() {
  echo "Stop hummingbird miner"
  docker-compose down
}

OTA_STATUS_FILE="/tmp/hummingbird_ota"

function checkOriginUpdate() {
  SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)

  git fetch origin `git rev-parse --abbrev-ref HEAD`

  HEADHASH=$(git rev-parse HEAD)
  UPSTREAMHASH=$(git rev-parse @{upstream})

  if [ "$HEADHASH" != "$UPSTREAMHASH" ]; then
  # stop docker-compose first
    if [ -f "$OTA_STATUS_FILE" ]; then
      echo "already in ota"
    else
      echo "Do self update"
      touch /tmp/hummingbird_ota
      stopHummingbirdMiner
      echo sudo "starting OTA"
      git stash
      git merge '@{u}'
      chmod +x ${SELF_NAME}
      exec sudo ./${SELF_NAME}
    fi
 fi
}

function cleanSavedSnapshot() {
  find /var/data/saved-snaps/ -type f -printf "%T@ %p\n" | sort -r | awk 'NR==2,NR=NRF {print $2}' | xargs -I {} rm {}
}

function restartMiner() {
  docker restart ${CONTAINER_MINER}
}

function minerLog() {
  bash ./miner_log.sh "$@"
}

function run() {
  echo ">>>>> hummingbirdiot start <<<<<<"
  echo ${SELF_NAME}
  patchDhcpcd
  patchHiotTimer
  tryWaitNetwork
  freeDiskPressure
  gitSetup
  checkPublicKeyfile
  checkOriginUpdate
  # unblock rfkill
  rfkill unblock all
  # WR for dhcpcd warinig
  sudo systemctl daemon-reload
  updateReleaseVersion
  setupDbus
  startHummingbird
  rm -f ${OTA_STATUS_FILE}
  cleanSavedSnapshot

  # hm-diag check and upgrade
  bash ./hm_diag_upgrade.sh

  exit 0
}

case $1 in
  run | '' )
    run ;;
  stop )
    stopHummingbirdMiner ;;
  restartMiner )
    restartMiner ;;
  minerLog )
    minerLog "$2" "$3" "$4" ;;
  * )
    echo "unknown subcommand !"
    exit 1
esac
