#/usr/bin/env bash

#loading context
. $1

cd terraform
./terraform.sh init
./terraform.sh apply 
cd ..
./get_ksqldb_api_key.sh
start_legacy_service $original_topic

