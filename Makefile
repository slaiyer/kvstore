SHELL:=/usr/bin/env bash

CLUSTER ?= kvstore
NS ?= kvstore
HOST ?= localhost
PORT ?= 8080

all: check-dep deploy-router deploy-redis deploy-prom-stack deploy-ingress

check-dep: check-dep-setup check-dep-test check-dep-build

check-dep-setup:
	command -v kind kubectl helm envsubst

check-dep-test:
	command -v k9s curl inso fortio redis-cli

check-dep-build:
	command -v python3 pip-compile docker

deploy-ingress: deploy-router
	kubectl apply -f ingress/ingress-nginx.yml
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=600s
	NS=$(NS) envsubst <ingress/ingress.yml | kubectl apply -f -

setup-cluster:
	-kind create cluster --name $(CLUSTER) \
		--config=<(PORT=$(PORT) envsubst <ingress/kind-cluster-config.yml)

teardown:
	kind delete cluster --name $(CLUSTER)

kind-load: build-dummy
	kind load docker-image $(IMAGE) --name $(CLUSTER)

set-context: setup-cluster
	kubectl config set-context kind-$(CLUSTER)

create-ns: set-context
	-kubectl create namespace $(NS)

deploy-prom-stack: create-ns helm-repos add-scrape-configs
	helm -n $(NS) upgrade --install prom-stack prometheus-community/kube-prometheus-stack \
		--set alertmanager.enabled=false --set grafana.enabled=false \
		--values prometheus/values.yml

deploy-redis: create-ns helm-repos
	helm -n $(NS) upgrade --install redis bitnami/redis \
		--set metrics.enabled=true

build-docker:
	$(MAKE) -C router build-docker

build-dummy:
	$(MAKE) -C router build-dummy

docker-prune:
	docker system prune -a

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

test-deploy-rollout: check-dep-test test-api
	${SHELL} tools/run-load-test.sh $(HOST) $(PORT) &
	sleep 10
	${SHELL} tools/switch-router-tag.sh $(NS)

view-fortio-reports:
	fortio report -quiet -data-dir test/fortio -http-port localhost:8888

forward-prometheus:
	kubectl port-forward -n kvstore pod/prometheus-prom-stack-kube-prometheus-prometheus-0 9090:9090 &

connect-redis:
	${SHELL} tools/connect-redis.sh
