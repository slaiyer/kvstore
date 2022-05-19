#!/usr/bin/env bash

HOST="${1:-localhost}"
PORT="${2:-8080}"
DURATION="${3:-1m}"
QPS="${4:-500}"
NUM_CONN="${5:-10}"
DATA_DIR="${6:-test/fortio}"

mkdir -p "${DATA_DIR}"
fortio load -quiet -data-dir "${DATA_DIR}" -a -c "${NUM_CONN}" -qps "${QPS}" -t "${DURATION}" -content-type 'application/json' -payload '{"key":"abc-1","value":"1"}' "http://${HOST}:${PORT}/set" &
fortio load -quiet -data-dir "${DATA_DIR}" -a -c "${NUM_CONN}" -qps "${QPS}" -t "${DURATION}" "http://${HOST}:${PORT}/get/abc-1" &
fortio load -quiet -data-dir "${DATA_DIR}" -a -c "${NUM_CONN}" -qps "${QPS}" -t "${DURATION}" "http://${HOST}:${PORT}/search?prefix=abc&suffix=-1" &
wait
echo 'Load test complete.'
