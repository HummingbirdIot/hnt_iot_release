#!/bin/bash

set -e

NAME=hm-diag

command -v jq > /dev/null || sudo apt-get install jq -y

function now_version() {
  local now_v=`dpkg -s ${NAME} | grep '^Status: deinstall' && echo "uninstalle" \
      || dpkg -s ${NAME} | grep '^Version: ' | cut -d: -f2`
  now_v=${now_v// /}
  echo "$now_v"
}

function new_version() {
  cat ./.hm-diag-version
}

function download_install() {
  local new_v=`new_version`
  local down_url="https://github.com/HummingbirdIot/hm-diag/releases/download/${new_v}/hm-diag_linux_arm64.deb" 
  if [ -f ".proxyconf"  ]; then
    proxy_type=`cat .proxyconf | jq '.releaseFileProxy.type'`
    proxy_type=${proxy_type//\"/}
    proxy_url=`cat .proxyconf | jq '.releaseFileProxy.value'`
    proxy_url=${proxy_url//\"/}
    if [ $proxy_type == "urlPrefix" ] && [ "$proxy_url" != "null" ]; then
      down_url="${proxy_url}${down_url}"
      echo "use proxy type: ${proxy_type} , prefix url: ${proxy_url} , download url: ${down_url}"
    elif [ $proxy_type == "mirror" ] && [ "$proxy_url" != "null" ]; then
      path=`echo $down_url | cut -d/ -f4-`
      down_url="$proxy_url$path"
      echo "use proxy type: ${proxy_type} , prefix url: ${proxy_url} , download url: ${down_url}"
    else
      echo "wrong proxy config, proxy type: ${proxy_type}, value: ${proxy_url} , ignore it."
    fi
  fi

  ts=`date +%s`
  TEMP_DEB="/tmp/${NAME}_${new_v}_$ts" &&
  wget -O "$TEMP_DEB" $down_url &&
  sudo dpkg -i "$TEMP_DEB"
  rm -f "$TEMP_DEB"
}

function upgrade_hm_diag() {
  local now_v=`now_version`
  local new_v=`new_version`

  if [ "$new_v" == "$now_v" ]; then
    echo "$NAME is the latest version, give up upgrade"
  else
    echo "to upgrade hm-diag ..."
    download_install
    echo "$NAME upgrade done"
  fi
}

function set_default_proxy() {
  if [  -f ".proxyconf" ]; then
    return
  fi

  cat << EOF > ./.proxyconf
{
  "releaseFileProxy": {
    "type": "urlPrefix",
    "value": "https://ghproxy.com/"
  }
}
EOF

  echo "set default github release proxy: `cat .proxyconf`"
}

set_default_proxy
upgrade_hm_diag
