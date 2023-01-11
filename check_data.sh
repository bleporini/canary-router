#!/usr/bin/env bash

. ./commons.sh $1

set -e

pause_rated_persistent_query
wait_for_0_lag

count_records(){
  docker run --rm -it -v $PWD:/work --workdir /work --network=host edenhill/kcat:1.7.1 -X security.protocol=SASL_SSL -X sasl.mechanism=PLAIN -X sasl.username=$API_KEY -X sasl.password=$API_SECRET -C -q -e -b $BOOTSTRAP_SERVER -t $1 -p $2 | wc -l
}

partitions=$(get_partition_count $original_topic)
i=0 

while [ $i -ne $partitions ]
do
	echo Computing the number of records in ${original_topic}_rated / p $i
	original_count=$(count_records ${original_topic}_rated $i)
	echo $original_count

	echo Computing the number of records in ${original_topic}_legacy / p $i
	legacy_count=$(count_records ${original_topic}_legacy $i)
	echo $legacy_count

	echo Computing the number of records in ${original_topic}_new / p $i
	new_count=$(count_records ${original_topic}_new $i)
	echo $new_count

	echo $original_count - $legacy_count - $new_count = $(($original_count - $legacy_count - $new_count))
	i=$(($i+1))
done

resume_rated_persistent_query
