#!/usr/bin/env bash

cd "${1:-src}" \
    && . venv/bin/activate \
    && python3 -m pip install --upgrade pip \
    && python3 -m pip install --upgrade pip-tools \
    && pip-compile --upgrade \
    && python3 -m pip install -r requirements.txt
