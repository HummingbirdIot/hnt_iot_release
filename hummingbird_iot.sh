#!/bin/bash
VERSION=0.7
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

function checkForNetwork() {
  tryNum=1
  while [ $tryNum -le 20 ]
  do
    ping -q -w 1 -c 1  `ip r | grep default | cut -d ' ' -f 3 | head -n 1` > /dev/null
    if [ $? -eq 0 ]; then
      return 0
    fi
    tryNum=$(( $tryNum + 1 ))
  done
  return -1
}

function checkMinerDiskUsage()
{
  usage=`df -h |grep '/dev/root' | awk '{print $5}' | tr -dc '0-9'`
  if ((usage > 80)); then
    echo "trim miner"
    exec sudo ./trim_miner.sh
  fi
}

function git_setup() {
  git config user.email "hummingbirdiot@example.com"
  git config user.name "hummingbirdiot"
}

function check_public_keyfile() {
  sudo touch /var/data/public_keys
}

function update_release_version() {
  diff ./config/lsb_release /etc/lsb_release >/dev/null 2>&1
  if [ $? -ne 0 ];then
    sudo cp ./config/lsb_release /etc/lsb_release
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
    sudo systemctl restart dbus
  fi
}

function startHummingbird() {
  echo "Start hummingbird "
  checkMinerDiskUsage
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
    sudo docker system prune -a -f
    docker-compose up -d
  else
    echo "no internal access???"
  fi

}

function stopHummingbirdMiner() {
  echo "Stop hummingbird miner"
  docker-compose down
}

OTA_STATUS_FILE="/tmp/hummingbird_ota"

function checkOriginUpdate() {
  SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)

  git fetch

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

echo ">>>>> hummingbirdiot start <<<<<<"
echo ${SELF_NAME}
checkForNetwork
git_setup
check_public_keyfile
checkOriginUpdate
# unblock rfkill
rfkill unblock all
update_release_version
setupDbus
startHummingbird
rm -f ${OTA_STATUS_FILE}

# hm-diag check and upgrade
source "$(dirname "$0")/hm_diag_upgrade.sh"
upgrade_hm_diag

exit 0
