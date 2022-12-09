#!/usr/bin/env bash 

#loading context
. $1

stop_legacy_service
stop_new_service

cd terraform
./terraform.sh destroy 
rm -rf ../etc
