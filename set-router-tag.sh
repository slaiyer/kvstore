#!/usr/bin/env bash

kubectl -n kvstore set image deployment/router-deployment router=router:"${1:-default}"
