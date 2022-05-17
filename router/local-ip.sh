#!/usr/bin/env bash

docker network ls | rg redisnet | cut -d' ' -f1 | xargs -I_ docker inspect _ | jq -r ".[0].Containers | .[] | select(.Name==\"${1:-router}\") | .IPv4Address" | cut -d'/' -f1
