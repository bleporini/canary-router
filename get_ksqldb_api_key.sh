#!/usr/bin/env bash

confluent environment list > /dev/null

if [ "$?" != "0" ] 
then
	echo Listing Confluent Cloud environments failed, you might not be logged in, please run \'confluent login --save\' before.
	exit 1
fi	

. ./etc/vars.sh

echo Creating API key for ksqlDB cluster $KSQLDB_ID
confluent environment use $ENV_ID

confluent api-key create --resource $KSQLDB_ID --description "For interacting with ksqlDB" --output json > etc/${KSQLDB_ID}_api_key.json
cat etc/${KSQLDB_ID}_api_key.json | jq --raw-output  '"KSQLDB_API_KEY=\(.key)"' >> etc/vars.sh
cat etc/${KSQLDB_ID}_api_key.json | jq --raw-output  '"KSQLDB_API_SECRET=\(.secret)"' >> etc/vars.sh

