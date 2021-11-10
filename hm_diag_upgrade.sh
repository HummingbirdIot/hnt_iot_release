#!/bin/bash

set -e

deb_name=hm-diag
url=https://api.github.com/repos/HummingbirdIot/hm-diag/releases/latest

command -v jq > /dev/null || sudo apt-get install jq -y

latest_res=`curl -s $url`
new_v=`echo $latest_res | jq '.tag_name'`
new_v=${new_v//\"/}

function is_installed() {
	if systemctl list-units --full -all | grep -q hm-diag.service; then
		echo yes
	else
		echo no
	fi
}

function to_update() {
		installed=`is_installed`
		if [ "$installed" == "no" ]; then
				echo yes
				return
		fi
		
		now_v=`dpkg -s hm-diag | grep Version | grep -v - | cut -d ':' -f 2`
		now_v=${now_v// /}

		if [ "$new_v" == "$now_v" ]; then 
				echo no
				return
		else
				echo yes
				return
		fi
}

function download_install() {
		down_url=`echo $latest_res | jq '.assets[3].browser_download_url'`
		down_url=${down_url//\"/}

		ts=`date +%s`
		TEMP_DEB="/tmp/${deb_name}_${new_v}_$ts" &&
		wget -O "$TEMP_DEB" $down_url &&
		sudo dpkg -i "$TEMP_DEB"
		rm -f "$TEMP_DEB"
}

function upgrade_hm_diag() {
		to_update=`to_update`
		if [[ "$to_update" != "yes" ]]; then
				echo $deb_name is the latest version, give up upgrade
		else
				echo to upgrade	hm-diag	...
				download_install
				echo "$deb_name upgrade done"
		fi
}
