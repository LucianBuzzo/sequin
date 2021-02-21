FROM balenalib/intel-nuc-debian

RUN curl -sSL https://dist.crystal-lang.org/apt/setup.sh | sudo bash

RUN curl -sL "https://keybase.io/crystal/pgp_keys.asc" | sudo apt-key add -
RUN echo "deb https://dist.crystal-lang.org/apt crystal main" | sudo tee /etc/apt/sources.list.d/crystal.list
RUN sudo apt-get update

# Install additional crystal dependencies
# For using OpenSSL
RUN sudo apt install libssl-dev
# For using XML
RUN sudo apt install libxml2-dev
# For using YAML
RUN sudo apt install libyaml-dev
# For using Big numbers
RUN sudo apt install libgmp-dev
# For using crystal play
RUN sudo apt install libz-dev

# install git so shards can be install from GitHub
RUN sudo apt install git

RUN sudo apt install crystal

# This will copy all files in our root to the working directory in the container
COPY . ./

# Install crystal dependencies
RUN shards install

CMD [ "crystal", "src/server.cr" ]
