.PHONY: \
	all\
	lint\
	test\
	validate-native

MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))

all:
	crystal src/sequin.cr

# Runs the github super linter in a docker container
lint:
	docker run -e RUN_LOCAL=true -v $(MAKEFILE_DIR):/tmp/lint github/super-linter

test:
	crystal spec

# Runs fast, GitHub-native validation checks for repo data + scripts
validate-native:
	node scripts/lint_repo.js
	node scripts/verify_chain.js
