#!/bin/bash
set -x
# usage eg: bash miner_log.sh  '2022-01-05 13:36:15' '2022-01-05 14:07:15' 'JSON up'
since="$1"
until="$2"
filter="$3"

journalctl -o short-iso CONTAINER_NAME=hnt_iot_packet-forwarder_1 -S "$since" -U "$until" --no-pager | grep "$filter" | sed s/\\s.*[0-9]*]://
