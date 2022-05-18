SHELL:=/usr/bin/env bash

setup-ingress: deploy-router
	kubectl apply -f ingress/ingress-nginx.yml
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=90s
	NS=$(NS) envsubst <ingress/ingress.yml | kubectl apply -f -

kind-create:
	-kind create cluster --name $(CLUSTER) \
		--config=<(PORT=$(PORT) envsubst <ingress/kind-cluster-config.yml)

kind-delete:
	kind delete cluster --name $(CLUSTER)

kind-load:
	kind load docker-image $(IMAGE) --name $(CLUSTER)

set-context: kind-create
	kubectl config set-context kind-$(CLUSTER)

create-ns: set-context
	-kubectl create namespace $(NS)

deploy-redis: create-ns helm-repos deploy-prom-stack
	helm -n $(NS) upgrade --install redis bitnami/redis \
		--values <(NS=$(NS) envsubst <redis/values.yml)

deploy-router: create-ns deploy-redis deploy-prom-stack
	make -C router build-dummy
	make kind-load IMAGE='router:default router:dummy' CLUSTER=$(CLUSTER)
	NS=$(NS) envsubst <router/k8s.yml | kubectl apply -f -

deploy-prom-stack: create-ns helm-repos add-scrape-configs
	helm -n $(NS) upgrade --install prom-stack prometheus-community/kube-prometheus-stack \
		--set kubeStateMetrics.enabled=false --set nodeExporter.enabled=false --set alertmanager.enabled=false \
		--values prometheus/values.yml
	#grafana admin password: prom-operator

add-scrape-configs: create-ns
	-kubectl -n $(NS) delete secret additional-scrape-configs
	kubectl -n $(NS) create secret generic additional-scrape-configs --from-file=prometheus/additional-scrape-configs.yml

helm-repos:
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	#helm repo update
