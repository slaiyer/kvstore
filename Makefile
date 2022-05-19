SHELL:=/usr/bin/env bash

all: check-dep deploy-router deploy-redis deploy-prom-stack setup-ingress

check-dep: check-dep-setup check-dep-test check-dep-build
	command -v kind kubectl docker helm envsubst

check-dep-test:
	command -v curl inso fortio redis-cli

check-dep-build:
	command -v python3 pip-compile

setup-ingress: deploy-router
	kubectl apply -f ingress/ingress-nginx.yml
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=600s
	NS=$(NS) envsubst <ingress/ingress.yml | kubectl apply -f -

kind-create:
	-kind create cluster --name $(CLUSTER) \
		--config=<(PORT=$(PORT) envsubst <ingress/kind-cluster-config.yml)

kind-delete:
	kind delete cluster --name $(CLUSTER)

kind-load: build-dummy
	kind load docker-image $(IMAGE) --name $(CLUSTER)

set-context: kind-create
	kubectl config set-context kind-$(CLUSTER)

create-ns: set-context
	-kubectl create namespace $(NS)

deploy-prom-stack: create-ns helm-repos add-scrape-configs
	helm -n $(NS) upgrade --install prom-stack prometheus-community/kube-prometheus-stack \
		--set kubeStateMetrics.enabled=false --set nodeExporter.enabled=false --set alertmanager.enabled=false \
		--values prometheus/values.yml
	#grafana admin password: prom-operator

deploy-redis: create-ns helm-repos
	helm -n $(NS) upgrade --install redis bitnami/redis \
		--set metrics.enabled=true

build-docker:
	$(MAKE) -C router build-docker

build-dummy:
	$(MAKE) -C router build-dummy

deploy-router: create-ns build-dummy
	$(MAKE) kind-load IMAGE='router:default router:dummy' CLUSTER=$(CLUSTER)
	NS=$(NS) envsubst <router/k8s.yml | kubectl apply -f -

add-scrape-configs: create-ns
	-kubectl -n $(NS) delete secret additional-scrape-configs
	kubectl -n $(NS) create secret generic additional-scrape-configs --from-file=prometheus/additional-scrape-configs.yml

helm-repos:
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

test-api: check-dep-test
	inso --verbose --ci --src test/insomnia/requests.json run test -e kvstore kvstore-expected

test-deploy-rollout: check-dep-test
	mkdir -p test/fortio
	fortio load -quiet -data-dir test/fortio -a -c 10 -qps 500 -t 30s -content-type 'application/json' -payload '{"key":"abc-1","value":"1"}' 'http://$(HOST):$(PORT)/set' &
	fortio load -quiet -data-dir test/fortio -a -c 10 -qps 500 -t 30s 'http://$(HOST):$(PORT)/get/abc-1' &
	fortio load -quiet -data-dir test/fortio -a -c 10 -qps 500 -t 30s 'http://$(HOST):$(PORT)/search?prefix=abc&suffix=-1' &
	sleep 10
	${SHELL} ./switch-router-tag.sh

view-fortio-reports:
	fortio report -quiet -data-dir test/fortio -http-port localhost:8888
