SHELL:=/usr/bin/env bash

PYTHON=$(shell ./py_checker.sh 3.10 python3 python)
ifeq (${PYTHON},)
$(error No usable python binary found)
endif

.PHONY: install test

install:
	${SHELL} dep-update.sh ${DIR}

test:
	PYTHONPATH=src ${PYTHON} -m unittest discover -s test
