#!/bin/bash
# Run OpenTitan Docker container
# Usage: ./docker-run.sh [command]
# If no command is provided, starts an interactive bash shell

set -e

OPENTITAN_DIR="$(pwd)/opentitan"

if [ -z "$1" ]; then
    # Interactive shell
    docker run -t -i \
        -v "${OPENTITAN_DIR}:/home/dev/src" \
        --env DEV_UID=$(id -u) --env DEV_GID=$(id -g) \
        opentitan:latest \
        bash
else
    # Execute command
    docker run -t \
        -v "${OPENTITAN_DIR}:/home/dev/src" \
        --env DEV_UID=$(id -u) --env DEV_GID=$(id -g) \
        opentitan:latest \
        bash -c "$@"
fi

