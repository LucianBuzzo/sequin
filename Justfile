set shell := ["bash", "-cu"]

# Run Sequin CLI entrypoint
all:
  ./sequin

# Run full test suite

test:
  crystal spec

# Run a single spec file, e.g. `just test-file spec/cli_spec.cr`
test-file spec_file:
  crystal spec {{spec_file}}

# Build local binary
build:
  mkdir -p .bin
  crystal build src/sequin_tool.cr -o .bin/sequin_tool

# Install local launcher into ~/bin (add ~/bin to PATH)
install-local:
  mkdir -p ~/bin
  cp ./sequin ~/bin/sequin
  chmod +x ~/bin/sequin
  @echo "Installed ~/bin/sequin"
  @echo "If needed: echo 'export PATH=\"$HOME/bin:$PATH\"' >> ~/.zshrc"

# Run GitHub super-linter locally in Docker
lint:
  docker run -e RUN_LOCAL=true -v "$(pwd)":/tmp/lint github/super-linter
