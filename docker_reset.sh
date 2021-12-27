#!/bin/bash
set -e

sudo service docker stop
sudo rm -rf /var/lib/docker
sudo service docker start
sudo bash ./hummingbird_iot.sh run
