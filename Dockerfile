FROM balenalib/intel-nuc-debian:20210201

RUN curl -sSL https://dist.crystal-lang.org/apt/setup.sh | bash

RUN curl -sL "https://keybase.io/crystal/pgp_keys.asc" | apt-key add -
RUN echo "deb https://dist.crystal-lang.org/apt crystal main" | tee /etc/apt/sources.list.d/crystal.list

RUN apt-get update && apt-get install -y\
  libssl-dev\
  libxml2-dev\
  libyaml-dev\
  libgmp-dev\
  libz-dev\
  git\
  crystal\
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# This will copy all files in our root to the working directory in the container
COPY . ./

# Install crystal dependencies
RUN shards install

CMD [ "bash", "run.sh" ]
