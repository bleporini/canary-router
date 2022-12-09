#!/usr/bin/env sh

. ./etc/vars.sh

#set -x
 
docker run $DOCKER_RUN_FLAGS --rm  \
	-v $PWD:/work --workdir /work \
	confluentinc/ksqldb-cli:0.28.2 ksql -u $KSQLDB_API_KEY -p $KSQLDB_API_SECRET $KSQLDB_ENDPOINT "$@"
	#confluentinc/ksqldb-cli:0.28.2 ./ksql_no_stderr.sh -u $KSQLDB_API_KEY -p $KSQLDB_API_SECRET $KSQLDB_ENDPOINT "$@"
