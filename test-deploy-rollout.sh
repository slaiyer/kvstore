#!/usr/bin/env bash

make -j$(nproc) test-deploy-rollout HOST=${1:-localhost} PORT=${2:-8080}
