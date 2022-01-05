#!/bin/bash

command -v jq > /dev/null || sudo apt-get install jq -y

# usage eg: bash miner_log.sh  '2022-01-05 13:36:15' '2022-01-05 14:07:15' 'JSON up'
since="$1"
until="$2"
filter="$3"

journalctl -o json CONTAINER_NAME=hnt_iot_packet-forwarder_1 -S "$since" -U "$until" | grep "$filter" | jq -c '{message:.MESSAGE, time: ._SOURCE_REALTIME_TIMESTAMP}'
