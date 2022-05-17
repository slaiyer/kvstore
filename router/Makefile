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

docker-build:
	docker build -t router .

local-redis-kvstore:
	-docker network create -d bridge redisnet
	-docker run --rm -d -p 6379:6379 --name redis --network redisnet redis

local-router: local-redis-kvstore
	docker run --rm -p 8000:8000 -e "REDIS_SERVICE_HOST=$(shell ${SHELL} local-ip.sh redis)" --name router --network redisnet router

gunicorn-local:
	cd src && . venv/bin/activate && gunicorn -b localhost:5000 router:APP

local-test:
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
	curl -s '$(ROUTER_HOST):$(ROUTER_PORT)/search?prefix=abc'
	curl -s '$(ROUTER_HOST):$(ROUTER_PORT)/search?suffix=-1'
	curl -s '$(ROUTER_HOST):$(ROUTER_PORT)/get/wat'
	curl -s '$(ROUTER_HOST):$(ROUTER_PORT)/set' -d 'key=wat&value=bruh'
	curl -s '$(ROUTER_HOST):$(ROUTER_PORT)/get/wat'
	curl -s '$(ROUTER_HOST):$(ROUTER_PORT)/set' -d 'key=wat&value=bruh'
	curl -s '$(ROUTER_HOST):$(ROUTER_PORT)/set' -d 'key=wat&value=bruh911'
	curl -s '$(ROUTER_HOST):$(ROUTER_PORT)/get/bruh'
	curl -s '$(ROUTER_HOST):$(ROUTER_PORT)/set' -d 'key=water&value=911'
	curl -s '$(ROUTER_HOST):$(ROUTER_PORT)/get/abc-2'

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
