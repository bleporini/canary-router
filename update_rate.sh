#!/usr/bin/env bash

#loading context
. ./commons.sh $1

clean etc/update_rate.sql


partitions=$(get_partition_count $original_topic)

offset_partition_criteria=$(cat etc/offset_partition_criteria)

# Create the queries
cat <<EOF > etc/update_rate.sql
create or replace stream original_rated with(kafka_topic='${original_topic}_rated', value_format='$value_format', key_format='$key_format') as
select *, random() <= $2 as for_new from original
where $offset_partition_criteria;
EOF

echo Updating running queries
DOCKER_RUN_FLAGS="-ti" ./ksql.sh -f etc/update_rate.sql

