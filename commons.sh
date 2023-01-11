#!/usr/bin/env bash

#preconditions
check_deps(){
 	tool=$1
	$tool --version
	if [ "$?" -ne "0" ];
	then
		echo Please check if $tool is correctly installed and also check \$PATH env var
	else
		echo $tool: ✅
	fi
}

check_file(){
	file=$1
	if [ -e $file ];
	then
		echo $file: ✅
	else
		echo $file can\'t be found
	fi
}

check_deps docker
check_deps jq

check_file ./etc/vars.sh
check_file $1

. ./etc/vars.sh
#loading context
. $1

clean(){
	if [ -e $1 ]
	then
	rm -f $1
	fi
}

docker_kafka="docker run -v $PWD:/work  --workdir /work -ti --rm confluentinc/cp-kafka:7.2.1"

get_offsets(){
	echo $($docker_kafka kafka-consumer-groups --command-config etc/kafka.properties --bootstrap-server $BOOTSTRAP_SERVER --describe --group $1  2>/dev/null | grep $2 | awk '{print $3, " ", $4}'|sort)
}

get_rated_query_id(){
	echo $(DOCKER_RUN_FLAGS="-a stdout" ./ksql.sh --execute "show queries;" --output JSON | jq -r '.[0].queries | map(select(.queryString | startswith("CREATE OR REPLACE STREAM ORIGINAL_RATED"))) | .[].id')
}

get_partition_count(){
	topic=$1
	echo $($docker_kafka kafka-topics --bootstrap-server $BOOTSTRAP_SERVER --describe --topic $topic --command-config etc/kafka.properties 2>/dev/null | grep PartitionCount | cut -d ":" -f 4 | cut  -f 1| sed 's/^ //')
}
pause_rated_persistent_query(){
	echo Pausing RATED persistent query
	query=$(get_rated_query_id)
	DOCKER_RUN_FLAGS="-a stdout" ./ksql.sh --execute "pause $query;"
}

get_lag(){
	group=$1
	topic=$2
	partition=$3
	echo $(docker run -v $PWD:/work  --workdir /work -ti --rm confluentinc/cp-kafka:7.2.1 kafka-consumer-groups --command-config etc/kafka.properties --bootstrap-server $BOOTSTRAP_SERVER --describe --group $group | grep "$topic *$partition"|awk '{print $6}')
}

wait_for_0_lag(){
	partitions=$(get_partition_count ${original_topic}_legacy)
	i=0
	while [ $i -ne $partitions ]
	do
		echo Checking lag for $legacy_service and $new_service on partitons $i
		legacy_lag=$(get_lag $legacy_service  ${original_topic}_legacy $i)
		new_lag=$(get_lag $new_service ${original_topic}_new $i)
		
		while [ "$legacy_lag$new_lag" -ne "00" ];
		do
		  echo Legacy service lag on partition $partition = $legacy_lag
		  echo New service lag on partition $partition    = $new_lag
		  sleep 2
                  legacy_lag=$(get_lag $legacy_service  ${original_topic}_legacy $i)
	          new_lag=$(get_lag $new_service ${original_topic}_new $i)
		done
		i=$(($i + 1))
	done
}	

resume_rated_persistent_query(){
	echo Resuming  RATED persistent query
	query=$(get_rated_query_id)
	DOCKER_RUN_FLAGS="-a stdout" ./ksql.sh --execute "resume $query;"
}
