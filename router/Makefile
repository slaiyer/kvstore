SHELL:=/usr/bin/env bash

PYTHON=$(shell ./py_checker.sh 3.10 python3 python)
ifeq (${PYTHON},)
$(error No usable python binary found)
endif

.PHONY: test

install:
	${SHELL} dep-update.sh ${DIR}
	# curl
	# jq
	# prometheus
# promql
	# redis-cli

gunicorn-local:
	cd src && . venv/bin/activate && gunicorn -b localhost:5000 router:APP

test:
	@$(MAKE) --no-print-directory kv-flush
	@$(MAKE) --no-print-directory kv-load
	@$(MAKE) --no-print-directory req-sample
	sleep 5
	@$(MAKE) --no-print-directory prom-local-endpoint-latency
	@$(MAKE) --no-print-directory prom-local-endpoint-status
	@$(MAKE) --no-print-directory prom-local-num-keys

kv-flush:
	redis-cli flushall

kv-load:
	redis-cli <test/pairs.txt

req-sample:
	curl -s 'localhost:5000/search?prefix=abc'
	curl -s 'localhost:5000/search?suffix=-1'
	curl -s 'localhost:5000/get/wat'
	curl -s 'localhost:5000/set' -d 'key=wat&value=bruh'
	curl -s 'localhost:5000/get/wat'
	curl -s 'localhost:5000/set' -d 'key=wat&value=bruh'
	curl -s 'localhost:5000/set' -d 'key=wat&value=bruh911'
	curl -s 'localhost:5000/get/bruh'
	curl -s 'localhost:5000/set' -d 'key=water&value=911'
	curl -s 'localhost:5000/get/abc-2'

prom-local-raw:
	watch -d -x curl -s 'http://localhost:5000/metrics'

prom-local-endpoint-latency:
	curl -s 'http://localhost:9090/api/v1/query' --data-urlencode 'query=sum by(endpoint) (flask_http_request_duration_seconds_sum) / sum by(endpoint) (flask_http_request_duration_seconds_count)' | jq '.data.result'
#promql --host "http://localhost:9090" 'sum by(endpoint) (flask_http_request_duration_seconds_sum) / sum by(endpoint) (flask_http_request_duration_seconds_count)'

prom-local-endpoint-status:
	curl -s 'http://localhost:9090/api/v1/query' --data-urlencode 'query=sum by(endpoint, status) (flask_http_request_duration_seconds_count)' | jq '.data.result'
#promql --host "http://localhost:9090" 'sum by(endpoint, status) (flask_http_request_duration_seconds_count)'

prom-local-num-keys:
	curl -s 'http://localhost:9090/api/v1/query' --data-urlencode 'query=topk by(timestamp) (1, num_keys_gauge)' | jq '.data.result'
#promql --host "http://localhost:9090" 'topk by(timestamp) (1, num_keys_gauge)'
