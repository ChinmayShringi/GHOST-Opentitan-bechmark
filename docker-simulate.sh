#!/bin/bash
# Simulate OpenTitan RTL in Docker
# Usage: ./docker-simulate.sh <target>

set -e

TARGET=${1:-"all"}

docker run -t \
    -v "$(pwd)/opentitan:/home/dev/src" \
    --env DEV_UID=$(id -u) --env DEV_GID=$(id -g) \
    opentitan:latest \
    bash -c "cd /home/dev/src && ./bazelisk.sh test ${TARGET}"

