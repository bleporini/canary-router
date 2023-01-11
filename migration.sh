#!/usr/bin/env bash
set -e

. ./commons.sh $1

clean etc/ddl.sl
clean etc/offsets

echo Stopping service
stop_legacy_service

echo Collecting last offset of legacy sercice
legacy_original_topic_offsets=$(get_offsets $legacy_service $original_topic) 

echo $legacy_original_topic_offsets > etc/offsets
offset_arr=($legacy_original_topic_offsets)
i=0
arr_size=${#offset_arr[@]}
offset_partition_criteria=""
echo $arr_size
while [ $i -ne $arr_size ]
do
        if [ $i -gt 0 ]
	then
		offset_partition_criteria="$offset_partition_criteria OR "
	fi
	offset_partition_criteria="$offset_partition_criteria (ROWPARTITION=${offset_arr[$i]} and ROWOFFSET > ${offset_arr[$i+1]}) "  

        i=$(($i+2))
done
echo $offset_partition_criteria > etc/offset_partition_criteria


partitions=$(get_partition_count $original_topic)

# Create the queries
cat <<EOF > etc/ddl.sql
SET 'auto.offset.reset'='earliest'; 
create or replace stream original (original_key $key_type key) with(kafka_topic='$original_topic', value_format='$value_format', key_format='$key_format');
create or replace stream original_rated with(kafka_topic='${original_topic}_rated', value_format='$value_format', key_format='$key_format') as 
select *, random() <= 0.1 as for_new from original 
where $offset_partition_criteria;
create or replace stream legacy_version with(kafka_topic='${original_topic}_legacy', value_format='$value_format', key_format='$key_format', partitions=$partitions) as select * from original_rated where for_new = false ;
create or replace stream new_version with(kafka_topic='${original_topic}_new', value_format='$value_format', key_format='$key_format', partitions=$partitions) as select * from original_rated where for_new = true ;
EOF


echo Creating ksqlDB queries
DOCKER_RUN_FLAGS="-ti" ./ksql.sh -f etc/ddl.sql

echo Starting legacy service on topic legacy rated topic
start_legacy_service ${original_topic}_legacy

echo Starting new  service on topic new rated topic
start_new_service  ${original_topic}_new


