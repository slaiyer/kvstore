SHELL:=/usr/bin/env bash

install:
	${SHELL} dep-update.sh ${DIR}

build-docker:
	docker build -t router:default .

build-dummy: build-docker
	cd dummy && docker build -t router:dummy .
