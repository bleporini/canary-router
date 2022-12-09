#!/usr/bin/env bash

#loading context
. ./commons.sh $1

clean etc/update_rate.sql

pause_rated_persistent_query
wait_for_0_lag


partitions=$(get_partition_count $original_topic)

# Create the queries
cat <<EOF > etc/update_rate.sql
create or replace stream legacy_version with(kafka_topic='${original_topic}_legacy', value_format='$value_format', key_format='$key_format', partitions=$partitions) as select * from original_rated where rate > $2 ;
create or replace stream new_version with(kafka_topic='${original_topic}_new', value_format='$value_format', key_format='$key_format', partitions=$partitions) as select * from original_rated where rate <= $2 ;
EOF

echo Updating running queries
DOCKER_RUN_FLAGS="-ti" ./ksql.sh -f etc/update_rate.sql

resume_rated_persistent_query
