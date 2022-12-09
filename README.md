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
                                    ,---->filter records where rate > threshold --> legacy topic --> legacy service
                                   /
original topic --> topic with rate 
                                   \
                                    `---->  filter records where rate <= threshold --> new topic --> new service
```

Updating the threshold is done with the following procedure:
1. Pause the rating query in order to stop the traffic to the services
2. Wait until the services have no lag
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
 ```
The initial threshold is 10% to be processed by the new service and 90% by the legacy. 

Then you can opt for 50% (or another value):

```bash
$ ./update_rate.sh services_examples/context.sh .9
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