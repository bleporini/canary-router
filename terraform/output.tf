resource "local_file" "config"{
        filename = "${path.cwd}/../etc/kafka.properties"
	content = <<-EOT
# Required connection configs for Kafka producer, consumer, and admin
bootstrap.servers=${replace(confluent_kafka_cluster.basic.bootstrap_endpoint, "SASL_SSL://", "")}
security.protocol=SASL_SSL
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='${confluent_api_key.app-manager-kafka-api-key.id}' password='${confluent_api_key.app-manager-kafka-api-key.secret}';
sasl.mechanism=PLAIN
# Required for correctness in Apache Kafka clients prior to 2.6
client.dns.lookup=use_all_dns_ips

# Best practice for higher availability in Apache Kafka clients prior to 3.0
session.timeout.ms=45000

# Best practice for Kafka producer to prevent data loss
acks=all

# Required connection configs for Confluent Cloud Schema Registry
schema.registry.url=${confluent_schema_registry_cluster.sr.rest_endpoint}
basic.auth.credentials.source=USER_INFO
basic.auth.user.info={{ SR_API_KEY }}:{{ SR_API_SECRET }}
  EOT
}

resource "local_file" "vars"{
  filename = "${path.cwd}/../etc/vars.sh"
  content = <<-EOT
#!/usr/bin/env bash
ENV_ID=${confluent_environment.canary-router.id}
BOOTSTRAP_SERVER=${replace(confluent_kafka_cluster.basic.bootstrap_endpoint, "SASL_SSL://", "")} 
API_KEY=${confluent_api_key.app-manager-kafka-api-key.id}
API_SECRET=${confluent_api_key.app-manager-kafka-api-key.secret}
KSQLDB_ENDPOINT=${confluent_ksql_cluster.app.rest_endpoint}
KSQLDB_ID=${confluent_ksql_cluster.app.id}
  EOT
}



output "cluster"{
	value = confluent_kafka_cluster.basic.bootstrap_endpoint
}

output "sr_endpoint"{
	value = confluent_schema_registry_cluster.sr.rest_endpoint
}

