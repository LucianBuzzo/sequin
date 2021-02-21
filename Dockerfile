FROM balenalib/intel-nuc-debian:20210201

RUN curl -sSL https://dist.crystal-lang.org/apt/setup.sh | bash

RUN curl -sL "https://keybase.io/crystal/pgp_keys.asc" | apt-key add -
RUN echo "deb https://dist.crystal-lang.org/apt crystal main" | tee /etc/apt/sources.list.d/crystal.list
RUN apt-get update

# Install additional crystal dependencies
# For using OpenSSL
RUN apt install libssl-dev
# For using XML
RUN apt install libxml2-dev
# For using YAML
RUN apt install libyaml-dev
# For using Big numbers
RUN apt install libgmp-dev
# For using crystal play
RUN apt install libz-dev

# install git so shards can be install from GitHub
RUN apt install git

RUN apt install crystal

# This will copy all files in our root to the working directory in the container
COPY . ./

# Install crystal dependencies
RUN shards install

CMD [ "crystal", "src/server.cr" ]
