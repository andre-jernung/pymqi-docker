#!/bin/bash

# Pick a tag from https://hub.docker.com/_/ubuntu?tab=description
UBUNTU_VERSION=ubuntu:24.04
MQ_VERSION=930

echo "Building pymqi image based on Ubuntu ${UBUNTU_VERSION}"
DOCKER_BUILDKIT=0 docker build . -t ubuntu-pymqi:${MQ_VERSION} --build-arg BASE_IMAGE=${UBUNTU_VERSION}
