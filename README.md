# Canary Router demo

The purpose of this repository is to showcase how you can implement a canary release routing between a producer and a consumer that needs to be upgraded to a new version. Usually you want to apply only a small part of the traffic to check if the new version doesn't come with major issue, then over time you want to increase the traffic to check that this new application meets the performance requirement. 
In a Kafka environment, the producer communicates with the consumer in a loose coupled manner through a **topic**.

Here the design is to leverage ksqlDB to act as a router between the emitting service and the downstream service. The basic requirements are:
- No impact on the emitting service: every operation has to be seamless
- No data loss
- Every message has to be processed by one and only one version of the service. 

## Design
The design is based on the assignment of a random rate to every record, then 2 content based routing ksqlDB persistent queries dispatch the records according to a defined threshold.

```
                                    ,----> filter records where rate > threshold --> legacy topic --> legacy service
                                   /
original topic --> topic with rate 
                                   \
                                    `---->  filter records where rate <= threshold --> new topic --> new service
```

Updating the threshold is done with the following procedure:
1. Pause the rating query in order to stop the traffic to the services
3. Update the CBR queries according to the new threshold
4. Restart the rating query

Finally, the promotion of the new service can be done:
1. Pause the rating query in order to stop the traffic to the services
2. Wait until the services have no lag
3. Collect the offsets committed by the new service to every partition of the topic
4. Compute the new offsets for this service by adding the initially saved offset at the beginning of migration procedure with the offsets committed to the downstream topic rated and filtered for the new service.

During the transition period, the data integrity can be checked by comparing the number of records in every partition, and it should be:
```
# records original topic - #records new topic - #records legacy topic == 0
```


## Running it
This demo is based on a set of `bash` scripts. The prerequisites are pretty simple: `bash`, `docker`, `confluent` [CLI](https://docs.confluent.io/confluent-cli/current/overview.html) and `jq`, period. All other tools are used in containers, limiting the dependencies at the minimum. Before using the scripts you have to run the following command in case you've never done this before :
```bash 
$ confluent login --save
```
This will allow the scripts to use the Confluent CLI without requesting your credentials every time. 

The streaming platform is [Confluent Cloud](https://confluent.cloud), so you have to use an existing account or [sign up](https://confluent.cloud/signup) (you will be entitled free credits to start). Then create a [cloud API key](https://docs.confluent.io/cloud/current/access-management/authenticate/api-keys/api-keys.html#cloud-cloud-api-keys) to be used to provision all streaming resources. 

The environment creation uses [Terraform](https://terrform.io) and the [Confluent Terraform provider](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs), but everything is wrapped in Docker container and orchestrated in the scripts. You can tweak the cloud provider and the region in the `terraform/variables.tf` file. All Confluent Cloud resources are set to the minimal.    

In order to keep all this logic generic, if you want to use it within your own environment, you have to provide a `bash` script that provides implementation for a couple of functions in order to control your services and a couple of variables. The demo is provided with dummy services that are nothing more than `kafka-console-consumer` properly set to use different group ids, to you can check `service_examples/context.sh` in order to build your own if needed.
## Set up
```bash
$ CONFLUENT_CLOUD_API_KEY=XXXXXXXXXXXX CONFLUENT_CLOUD_API_SECRET=XXXXXXXXXXXXXXXXXXXXXXXX ./setup.sh services_examples/context.sh
[...]
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
[...]
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

cluster = "SASL_SSL://pkc-xxxxx.uaenorth.azure.confluent.cloud:9092"
sr_endpoint = "https://psrc-xxxxxx.westeurope.azure.confluent.cloud"
Creating API key for ksqlDB cluster lksqlc-7nnjkj
Now using "env-xxxx" as the default (active) environment.
```
It usually takes around 10/15 minutes.

The `setup.sh` script automatically starts the demo with the dummy legacy service. 

## Run the migration
```bash
 $ ./migration.sh services_examples/context.sh
 Docker version 20.10.20, build 9fdeb9c
docker: ✅
jq-1.6
jq: ✅
./etc/vars.sh: ✅
services_examples/context.sh: ✅
Stopping service
service_v1
Collecting last offset of legacy sercice
12
Creating ksqlDB queries
[...]
 Created query with ID CSAS_NEW_VERSION_7
------------------------------------------
Starting legacy service on topic legacy rated topic
Starting new service on topic new rated topic
 ```
The initial threshold is 10% to be processed by the new service and 90% by the legacy.

After a while, you can also run a script that checks the number of messages is consistent with the expectation of not losing any message and avoiding any duplicates. It's not a proper proof point as it would require to dump the 3 topics and check record per record.

```bash 
./check_data.sh services_examples/context.sh
Docker version 20.10.20, build 9fdeb9c
docker: ✅
jq-1.6
jq: ✅
./etc/vars.sh: ✅
services_examples/context.sh: ✅
Pausing RATED persistent query

 Message

 Query paused.

Checking lag for service_v1 and service_v2 on partitons 0
Checking lag for service_v1 and service_v2 on partitons 1
Checking lag for service_v1 and service_v2 on partitons 2
Checking lag for service_v1 and service_v2 on partitons 3
Checking lag for service_v1 and service_v2 on partitons 4
Checking lag for service_v1 and service_v2 on partitons 5
Computing the number of records in orders_rated / p 0
297
Computing the number of records in orders_legacy / p 0
269
Computing the number of records in orders_new / p 0
28
297 - 269 - 28 = 0
Computing the number of records in orders_rated / p 1
274
Computing the number of records in orders_legacy / p 1
249
Computing the number of records in orders_new / p 1
25
274 - 249 - 25 = 0
Computing the number of records in orders_rated / p 2
317
Computing the number of records in orders_legacy / p 2
292
Computing the number of records in orders_new / p 2
25
317 - 292 - 25 = 0
Computing the number of records in orders_rated / p 3
296
Computing the number of records in orders_legacy / p 3
273
Computing the number of records in orders_new / p 3
23
296 - 273 - 23 = 0
Computing the number of records in orders_rated / p 4
275
Computing the number of records in orders_legacy / p 4
244
Computing the number of records in orders_new / p 4
31
275 - 244 - 31 = 0
Computing the number of records in orders_rated / p 5
302
Computing the number of records in orders_legacy / p 5
268
Computing the number of records in orders_new / p 5
34
302 - 268 - 34 = 0
Resuming RATED persistent query

 Message

 Query resumed.
```
The output should highlight that removing the number of messages stored into the new topics and into the legacy topic from the number of messages in the orginal rated topic shall result in exactly 0 messages. 
You can also use this script to check the ratio of messages processed by the new service and the legacy one.

Then you can opt for 50% (or another value):

```bash
$ ./update_rate.sh services_examples/context.sh .5
Docker version 20.10.20, build 9fdeb9c
docker: ✅
jq-1.6
jq: ✅
./etc/vars.sh: ✅
services_examples/context.sh: ✅
Pausing RATED persistent query

 Message

 Query paused.

Checking lag for service_v1 and service_v2 on partitons 0
Checking lag for service_v1 and service_v2 on partitons 1
Checking lag for service_v1 and service_v2 on partitons 2
Checking lag for service_v1 and service_v2 on partitons 3
Checking lag for service_v1 and service_v2 on partitons 4
Checking lag for service_v1 and service_v2 on partitons 5
Updating running queries
OpenJDK 64-Bit Server VM warning: Option UseConcMarkSweepGC was deprecated in version 9.0 and will likely be removed in a future release.

CREATE OR REPLACE STREAM LEGACY_VERSION WITH (KAFKA_TOPIC='orders_legacy', KEY_FORMAT='kafka', PARTITIONS=6, REPLICAS=3, VALUE_FORMAT='json_sr') AS SELECT *
FROM ORIGINAL_RATED ORIGINAL_RATED
WHERE (ORIGINAL_RATED.RATE > 0.5)
EMIT CHANGES;
 Message
---------------------------------------------
 Created query with ID CSAS_LEGACY_VERSION_5
---------------------------------------------

CREATE OR REPLACE STREAM NEW_VERSION WITH (KAFKA_TOPIC='orders_new', KEY_FORMAT='kafka', PARTITIONS=6, REPLICAS=3, VALUE_FORMAT='json_sr') AS SELECT *
FROM ORIGINAL_RATED ORIGINAL_RATED
WHERE (ORIGINAL_RATED.RATE <= 0.5)
EMIT CHANGES;
 Message
------------------------------------------
 Created query with ID CSAS_NEW_VERSION_7
------------------------------------------
Resuming RATED persistent query

 Message

 Query resumed.
```

The next step is promoting the new service to process 100% of the messages from the original topic, shutting down the legacy and disposing the canary router structure:

```bash 
$  ./promoting_new.sh services_examples/context.sh
Docker version 20.10.20, build 9fdeb9c
docker: ✅
jq-1.6
jq: ✅
./etc/vars.sh: ✅
services_examples/context.sh: ✅
Pausing RATED persistent query

 Message

 Query paused.

Checking lag for service_v1 and service_v2 on partitons 0
Checking lag for service_v1 and service_v2 on partitons 1
Checking lag for service_v1 and service_v2 on partitons 2
Checking lag for service_v1 and service_v2 on partitons 3
Checking lag for service_v1 and service_v2 on partitons 4
Checking lag for service_v1 and service_v2 on partitons 5
service_v2
service_v1
orders / Partition 0: Offset was 254, offset for new services after migration will be 385 (254 + 131 )
orders / Partition 3: Offset was 247, offset for new services after migration will be 400 (247 + 153 )
orders / Partition 1: Offset was 224, offset for new services after migration will be 384 (224 + 160 )
orders / Partition 5: Offset was 233, offset for new services after migration will be 384 (233 + 151 )
orders / Partition 2: Offset was 225, offset for new services after migration will be 378 (225 + 153 )
orders / Partition 4: Offset was 256, offset for new services after migration will be 427 (256 + 171 )
[2022-12-14 07:22:41,044] WARN The configuration 'schema.registry.url' was supplied but isn't a known config. (org.apache.kafka.clients.admin.AdminClientConfig)
[2022-12-14 07:22:41,044] WARN The configuration 'basic.auth.user.info' was supplied but isn't a known config. (org.apache.kafka.clients.admin.AdminClientConfig)
[2022-12-14 07:22:41,044] WARN The configuration 'basic.auth.credentials.source' was supplied but isn't a known config. (org.apache.kafka.clients.admin.AdminClientConfig)
[2022-12-14 07:22:41,045] WARN The configuration 'acks' was supplied but isn't a known config. (org.apache.kafka.clients.admin.AdminClientConfig)
[2022-12-14 07:22:41,045] WARN The configuration 'session.timeout.ms' was supplied but isn't a known config. (org.apache.kafka.clients.admin.AdminClientConfig)

GROUP                          TOPIC                          PARTITION  NEW-OFFSET
service_v2                     orders                         0          385
service_v2                     orders                         3          400
service_v2                     orders                         1          384
service_v2                     orders                         5          384
service_v2                     orders                         2          378
service_v2                     orders                         4          427
Disposing useless resources
OpenJDK 64-Bit Server VM warning: Option UseConcMarkSweepGC was deprecated in version 9.0 and will likely be removed in a future release.

DROP STREAM LEGACY_VERSION;
 Message
-------------------------------------------------------------
 Source `LEGACY_VERSION` (topic: orders_legacy) was dropped.
-------------------------------------------------------------

DROP STREAM NEW_VERSION;
 Message
-------------------------------------------------------
 Source `NEW_VERSION` (topic: orders_new) was dropped.
-------------------------------------------------------

DROP STREAM ORIGINAL_RATED;
 Message
------------------------------------------------------------
 Source `ORIGINAL_RATED` (topic: orders_rated) was dropped.
------------------------------------------------------------

drop stream original;
 Message
------------------------------------------------
 Source `ORIGINAL` (topic: orders) was dropped.
------------------------------------------------
Starting new service on the original topic
```

And ultimately you can dispose everything:

```bash
 $ ./teardown.sh services_examples/context.sh
 [...]
Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes
  [...]
Destroy complete! Resources: 10 destroyed.
$ 
 ```