#!/usr/bin/env bash

CLUSTER="${1:-kvstore}"
NS="${2:-kvstore}"
PORT="${3:-8080}"

MAKE_ARGS="CLUSTER=${CLUSTER} NS=${NS} PORT=${PORT}"

make -j$(nproc) kind-delete ${MAKE_ARGS}
