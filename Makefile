.PHONY: \
	all\
	lint\
	test

MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))

all:
	crystal src/sequin.cr

# Runs the github super linter in a docker container
lint:
	docker run -e RUN_LOCAL=true -v $(MAKEFILE_DIR):/tmp/lint github/super-linter

SPECS := $(filter-out spec/server_spec.cr,$(wildcard spec/*_spec.cr))

test:
	crystal spec $(SPECS)
