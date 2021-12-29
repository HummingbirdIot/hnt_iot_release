#!/bin/bash

set -ex

NAME=hm-diag
PKG=${NAME}_linux_arm64.deb

new_v=`dpkg-deb -W ./$PKG | cut -f2`

now_v=`dpkg -s ${NAME} | grep '^Status: deinstall' && echo "uninstalle" \
    || dpkg -s ${NAME} | grep '^Version: ' | cut -d: -f2`
now_v=${now_v// /}

if [ "$new_v" == "$now_v" ]; then
  echo "$NAME is the latest version, give up upgrade"
  exit 0
fi

echo "to upgrade ${NAME} ..."
sudo dpkg -i "$PKG" 
echo "$NAME upgrade done"
