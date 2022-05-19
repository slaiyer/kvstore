#!/usr/bin/env bash

host="${1:-localhost}"
port="${2:-8080}"
data_dir="${3:-test/fortio}"
num_conn="${4:-10}"
qps="${5:-500}"
duration="${6:-30s}"

mkdir -p "${data_dir}"
fortio load -quiet -data-dir "${data_dir}" -a -c "${num_conn}" -qps "${qps}" -t "${duration}" -content-type 'application/json' -payload '{"key":"abc-1","value":"1"}' "http://${host}:${port}/set" &
fortio load -quiet -data-dir "${data_dir}" -a -c "${num_conn}" -qps "${qps}" -t "${duration}" "http://${host}:${port}/get/abc-1" &
fortio load -quiet -data-dir "${data_dir}" -a -c "${num_conn}" -qps "${qps}" -t "${duration}" "http://${host}:${port}/search?prefix=abc&suffix=-1" &
