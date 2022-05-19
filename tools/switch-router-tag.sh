#!/usr/bin/env bash

NS="${1:-kvstore}"

get_router_tag() {
    kubectl -n "${1}" get deployment/router-deployment -o=jsonpath='{..image}' \
        | cut -d: -f2
}

set_router_tag() {
    kubectl -n "${1}" set image deployment/router-deployment router=router:"${2}"
}

if [[ $(get_router_tag "${NS}") == default ]]; then
    set_router_tag "${NS}" dummy
else
    set_router_tag "${NS}" default
fi
