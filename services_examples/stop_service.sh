#!/usr/bin/env sh 

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker:latest stop $1
