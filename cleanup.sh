#!/usr/bin/env bash


docker stop service_v1;
docker stop service_v2;

DOCKER_RUN_FLAGS="-ti" ./ksql.sh -f cleanup.sql

./services_examples/start_service.sh service_v1 orders
