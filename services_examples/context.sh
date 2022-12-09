#!/usr/bin/env sh 

#set -x 

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

original_topic=orders
value_format=json_sr
key_format=kafka
key_type=string
legacy_service=service_v1
new_service=service_v2

stop_legacy_service () {
  $SCRIPT_DIR/stop_service.sh $legacy_service
}

start_legacy_service () {
  $SCRIPT_DIR/start_service.sh $legacy_service $1 
}

stop_new_service () {
  $SCRIPT_DIR/stop_service.sh $new_service
}

start_new_service () {
  $SCRIPT_DIR/start_service.sh $new_service $1 
}
