set shell := ["bash", "-cu"]

# Run Sequin CLI entrypoint
all:
  ./sequin

# Run test suite

test:
  crystal spec

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
