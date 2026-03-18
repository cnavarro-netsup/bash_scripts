SHELL := /usr/bin/env bash

.PHONY: checks checks-all checks-factorial checks-suma

checks:
	./ci/run_checks.sh

checks-all: checks

checks-factorial:
	./ci/run_checks.sh -p factorial

checks-suma:
	./ci/run_checks.sh -p suma
