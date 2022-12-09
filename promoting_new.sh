#!/usr/bin/env bash 

. ./commons.sh $1

clean etc/new_offsets

pause_rated_persistent_query
wait_for_0_lag


original_offsets=$(cat etc/offsets)
original_offsets_arr=($original_offsets)

new_service_offsets=$(get_offsets $new_service ${original_topic}_new)
new_service_offsets_arr=($new_service_offsets)

stop_new_service
stop_legacy_service
arr_size=${#original_offsets_arr[@]}
i=0
while [ $i -ne $arr_size ]
do
	partition=${original_offsets_arr[$i]}
	offset=${original_offsets_arr[$i+1]}
	offset_in_new_topic=${new_service_offsets_arr[$i+1]}
	new_offset=$(($offset + $offset_in_new_topic))
	echo $original_topic / Partition $partition: Offset was $offset, offset for new services after migration will be $new_offset \($offset + $offset_in_new_topic \)
	echo $original_topic,$partition,$new_offset >> etc/new_offsets

	i=$(($i+2))
done
$docker_kafka kafka-consumer-groups --command-config etc/kafka.properties --bootstrap-server $BOOTSTRAP_SERVER --group $new_service --reset-offsets --from-file etc/new_offsets --execute
echo Disposing useless resources
DOCKER_RUN_FLAGS="-ti" ./ksql.sh -f cleanup.sql

echo Starting new service on the original topic
start_new_service $new_service $original_topic






