#!/usr/bin/env bash

HOST="${1:-localhost}"
PORT="${2:-8080}"
DATA_DIR="${3:-test/fortio}"
NUM_CONN="${4:-10}"
QPS="${5:-500}"
DURATION="${6:-30s}"

mkdir -p "${DATA_DIR}"
fortio load -quiet -data-dir "${DATA_DIR}" -a -c "${NUM_CONN}" -qps "${QPS}" -t "${DURATION}" -content-type 'application/json' -payload '{"key":"abc-1","value":"1"}' "http://${HOST}:${PORT}/set" &
fortio load -quiet -data-dir "${DATA_DIR}" -a -c "${NUM_CONN}" -qps "${QPS}" -t "${DURATION}" "http://${HOST}:${PORT}/get/abc-1" &
fortio load -quiet -data-dir "${DATA_DIR}" -a -c "${NUM_CONN}" -qps "${QPS}" -t "${DURATION}" "http://${HOST}:${PORT}/search?prefix=abc&suffix=-1" &
wait
echo 'Load test complete.'
