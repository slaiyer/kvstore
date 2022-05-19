SHELL:=/usr/bin/env bash

all: check-dep-req deploy-router deploy-redis deploy-prom-stack setup-ingress #check-dep-opt

check-dep-req:
	command -v kind kubectl docker helm envsubst curl inso redis-cli

check-dep-opt:
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
	#helm repo update
