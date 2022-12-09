# Configure the Confluent Provider
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.16.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key    # optionally use CONFLUENT_CLOUD_API_KEY env var
  cloud_api_secret = var.confluent_cloud_api_secret # optionally use CONFLUENT_CLOUD_API_SECRET env var
}

resource "confluent_environment" "canary-router" {
  display_name = "canary-router"
}

resource "confluent_kafka_cluster" "basic" {
  display_name = "canary-router-poc"
  availability = "SINGLE_ZONE"
  cloud        = var.cloud
  region       = var.region
  basic {}

  environment {
    id = confluent_environment.canary-router.id
  }

}

resource "confluent_schema_registry_cluster" "sr" {
  package = "ESSENTIALS"

  environment {
    id = confluent_environment.canary-router.id
  }

  region {
    # See https://docs.confluent.io/cloud/current/stream-governance/packages.html#stream-governance-regions
    # Schema Registry and Kafka clusters can be in different regions as well as different cloud providers,
    # but you should to place both in the same cloud and region to restrict the fault isolation boundary.
    id = var.sr_region
  }

}

resource "confluent_service_account" "app-manager" {
  display_name = "app-manager"
  description  = "Service account to manage 'inventory' Kafka cluster"
}

resource "confluent_role_binding" "app-manager-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

resource "confluent_ksql_cluster" "app" {
  display_name = "app"
  csu          = 2
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  credential_identity {
    id = confluent_service_account.app-manager.id
  }
  environment {
    id = confluent_environment.canary-router.id
  }
  depends_on = [
    confluent_kafka_topic.orders,
    confluent_schema_registry_cluster.sr,
    confluent_role_binding.app-manager-kafka-cluster-admin
  ]
}


resource "confluent_api_key" "app-manager-kafka-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.canary-router.id
    }
  }
}

resource "confluent_kafka_topic" "orders"{
    topic_name  = "orders"
    partitions_count = 6

    kafka_cluster {
      id = confluent_kafka_cluster.basic.id
    }
    rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
    credentials {
      key    = confluent_api_key.app-manager-kafka-api-key.id
      secret = confluent_api_key.app-manager-kafka-api-key.secret
   }

  depends_on = [
    confluent_role_binding.app-manager-kafka-cluster-admin
  ]
}

resource "confluent_connector" "source" {
  environment {
    id = confluent_environment.canary-router.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_sensitive = {}

  config_nonsensitive = {
    "connector.class"          = "DatagenSource"
    "name"                     = "DatagenSourceConnector_0"
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.app-manager.id
    "kafka.topic"              = confluent_kafka_topic.orders.topic_name
    "output.data.format"       = "JSON_SR"
    "quickstart"               = "ORDERS"
    "tasks.max"                = "1"
  }
  depends_on = [
    confluent_kafka_topic.orders,
    confluent_role_binding.app-manager-kafka-cluster-admin
  ]

}

