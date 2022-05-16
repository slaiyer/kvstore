SHELL:=/usr/bin/env bash

PYTHON=$(shell ./py_checker.sh 3.10 python3 python)
ifeq (${PYTHON},)
$(error No usable python binary found)
endif

.PHONY: install test

install:
	${SHELL} dep-update.sh ${DIR}

gunicorn-local:
	cd src && . venv/bin/activate && gunicorn -b localhost:5000 router:APP

prom-local-raw:
	watch -d -x curl -s 'http://localhost:5000/metrics'

prom-local-endpoint-latency:
	promql --host "http://localhost:9090" 'sum by(endpoint) (flask_http_request_duration_seconds_sum) / sum by(endpoint) (flask_http_request_duration_seconds_count)'

prom-local-endpoint-status:
	promql --host "http://localhost:9090" 'sum by(endpoint, status) (flask_http_request_duration_seconds_count)' 

prom-local-num-keys:
	promql --host "http://localhost:9090" 'topk by(timestamp) (1, num_keys_gauge)'

test:
	PYTHONPATH=src ${PYTHON} -m unittest discover -s test
