FROM clux/muslrust:1.95.0-nightly

USER root

RUN apt update && \
    apt upgrade -y && \
    apt install -y libpq-dev wget

# install cargo-chef, used to compile dependencies separately from the
# application code, which allows for caching a Docker layer with the compiled
# dependencies. If the dependencies don't change, the cached layer is used, and
# sccache is not.
RUN cargo install cargo-chef --version ^0.1

# tell rustc to use sccache as a wrapper and set the cache directory
ENV RUSTC_WRAPPER=sccache \
    SCCACHE_DIR=/sccache

# set the working directory for the subsequent stages
WORKDIR /app
