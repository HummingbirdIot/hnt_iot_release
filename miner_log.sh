#!/bin/bash

command -v jq > /dev/null || sudo apt-get install jq -y

function fwdLog(){
  # eg: '2022-01-05 13:36:15' '2022-01-05 14:07:15' 'JSON up'
  local since="$1"
  local until="$2"
  local filter="$3"

  journalctl -o json CONTAINER_NAME=hnt_iot_packet-forwarder_1 \
    -S "$since" -U "$until" \
    | grep "$filter" \
    | jq -c '{message:.MESSAGE, time: ._SOURCE_REALTIME_TIMESTAMP}'
}

function minerLog() {
  local filter="$1"
  local maxLine=$2
  cat /var/data/log/console.log \
    | grep "$filter" \
    | tail -n $maxLine \
    | awk '{
        t=$1" "$2;
        for(i=1; i<=3; i++){ $i="" }; msg=$0;
        gsub("\"", "\\\"", msg);
        gsub(/^[ \t]+/, "", msg);
        printf "{\"time\": \"%s\", \"message\":\"%s\"}\n", t,msg
      }'
}

case $1 in
  miner )
   minerLog "$2" $3 ;;
  pktfwd )
    fwdLog "$2" "$3" "$4" ;;
  * )
    echo "unknown log type"
    exit 1 ;;
esac
