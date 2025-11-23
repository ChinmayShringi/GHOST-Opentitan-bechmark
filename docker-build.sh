#!/bin/bash
# Build OpenTitan Docker container
# Usage: ./docker-build.sh

set -e

cd opentitan
docker build -t opentitan:latest -f util/container/Dockerfile .

