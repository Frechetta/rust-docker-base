FROM clux/muslrust:1.95.0-nightly

ARG SCCACHE_VERSION=0.14.0

USER root

RUN apt update && \
    apt upgrade -y && \
    apt install -y libpq-dev wget

# 1. install sccache, used to cache compiled dependencies so that only the updated
#      dependencies have to be recompiled rather than all of them each time a
#      Cargo.toml file is updated.
# 2. install cargo-chef, used to compile dependencies separately from the
#      application code, which allows for caching a Docker layer with the compiled
#      dependencies. If the dependencies don't change, the cached layer is used, and
#      sccache is not.
RUN wget https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    && tar -xzf sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    && mv sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl/sccache /usr/local/bin/sccache \
    && chmod +x /usr/local/bin/sccache && \
    cargo install cargo-chef --version ^0.1

# tell rustc to use sccache as a wrapper and set the cache directory
ENV RUSTC_WRAPPER=sccache \
    SCCACHE_DIR=/sccache

# set the working directory for the subsequent stages
WORKDIR /app
