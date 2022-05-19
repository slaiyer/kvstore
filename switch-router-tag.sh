#!/usr/bin/env bash

if [[ $(./get-router-tag.sh) == default ]]; then
    ./set-router-tag.sh dummy
else
    ./set-router-tag.sh default
fi
