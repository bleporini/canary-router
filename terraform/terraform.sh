#!/usr/bin/env bash 

#set -x 
docker run -ti --rm -v $PWD:/work/terraform -v $PWD/../:/work --workdir /work/terraform \
	-e TF_VAR_confluent_cloud_api_key=$CONFLUENT_CLOUD_API_KEY \
	-e TF_VAR_confluent_cloud_api_secret=$CONFLUENT_CLOUD_API_SECRET \
	-e TF_LOG=ERROR \
	hashicorp/terraform:1.3.5 "$@"
	#--entrypoint "/bin/sh" hashicorp/terraform:1.3.5 
	#-e TF_LOG=TRACE \
	#-e TF_LOG=ERROR \

