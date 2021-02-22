FROM balenalib/intel-nuc-debian:20210201

# See https://github.com/hadolint/hadolint/wiki/DL4006#rationale
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN curl -sSL https://dist.crystal-lang.org/apt/setup.sh | bash

RUN curl -sL "https://keybase.io/crystal/pgp_keys.asc" | apt-key add -
RUN echo "deb https://dist.crystal-lang.org/apt crystal main" | tee /etc/apt/sources.list.d/crystal.list

RUN apt-get update &&\
  apt-get install -y --no-install-recommends\
  libssl-dev=1.1.1d-0+deb10u5\
  libxml2-dev=2.9.4+dfsg1-7+deb10u1\
  libyaml-dev=0.2.1-1\
  libgmp-dev=2:6.1.2+dfsg-4\
  # libz-dev=1.2.1.1\
  zlib1g-dev=1:1.2.11.dfsg-1\
  git=1:2.20.1-2+deb10u3\
  crystal=0.35.1-1\
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# This will copy all files in our root to the working directory in the container
COPY . ./

# Install crystal dependencies
RUN shards install

CMD [ "bash", "run.sh" ]
