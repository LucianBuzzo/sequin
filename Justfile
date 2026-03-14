set shell := ["bash", "-cu"]

# Run Sequin CLI entrypoint
all:
  crystal src/sequin.cr

# Run test suite

test:
  crystal spec

# Run GitHub super-linter locally in Docker
lint:
  docker run -e RUN_LOCAL=true -v "$(pwd)":/tmp/lint github/super-linter
