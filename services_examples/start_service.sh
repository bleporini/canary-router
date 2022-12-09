#!/usr/bin/env sh

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

. $SCRIPT_DIR/../etc/vars.sh

service_name=$1
topic=$2

#set -x

docker run -d --rm -v $SCRIPT_DIR/../etc:$PWD  --workdir $PWD  --name $service_name confluentinc/cp-kafka:7.2.1 kafka-console-consumer \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --consumer.config kafka.properties \
  --consumer-property group.id=$service_name \
  --consumer-property client.id=$service_name \
  --topic $topic  > /dev/null
