#!/usr/bin/env bash

kubectl -n kvstore get deployment/router-deployment -o=jsonpath='{..image}' \
    | cut -d: -f2
