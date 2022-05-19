#!/usr/bin/env bash

ns=kvstore
lport=6379
name=svc/redis-master
rport=6379

# This would show that the port is closed
# nmap -sT -p $lport lhost || true

kubectl -n "${ns}" port-forward "${name}" "${lport}":"${rport}" >/dev/null 2>&1 &

pid="${!}"

trap '{
    kill "${pid}"
}' EXIT

while ! nc -vz localhost "${lport}" >/dev/null 2>&1; do
    sleep 0.1
done

REDIS_PASSWORD="$(kubectl get secret -n kvstore redis -o jsonpath="{.data.redis-password}" | base64 --decode)"
REDISCLI_AUTH="${REDIS_PASSWORD}" redis-cli
