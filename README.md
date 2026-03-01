# Rust Docker Base

A Docker image meant to be used as a base image for building Rust apps.

This base image and the typical usage are inspired by:
- https://depot.dev/blog/rust-dockerfile-best-practices
- https://www.dermitch.de/post/rust-docker-sccache/

## Example

```dockerfile
### PLANNER STAGE ###
FROM frechetta93/rust-build-base:latest AS planner

# copy the source code into the stage and run `cargo chef prepare` to generate a
# recipe.json file with the project skeleton. This will be used in the next stage to
# compile the dependencies separately from the application code.
# note that we are utilizing two caches:
#   - the cargo registry cache, which caches downloaded dependencies' source code
#   - the sccache cache, which caches compiled dependencies
COPY . .
RUN --mount=type=cache,target=$CARGO_HOME/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo chef prepare --recipe-path recipe.json

### BUILDER STAGE ###
FROM frechetta93/rust-build-base:latest AS builder

# copy the recipe.json file from the planner stage and run `cargo chef cook` to compile
# the dependencies. If the dependencies don't change between builds, this cached layer
# will be used. Otherwise, sccache will be used.
COPY --from=planner /app/recipe.json recipe.json
RUN --mount=type=cache,target=$CARGO_HOME/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json

# copy the source code into the stage and build the application.
COPY ..

RUN --mount=type=cache,target=$CARGO_HOME/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo build --release --target x86_64-unknown-linux-musl --bin app

### FINAL IMAGE ###
FROM alpine:3.23

ARG USER=app

RUN apk add dumb-init && \
    addgroup -S ${USER} && \
    adduser -S -H ${USER} ${USER}

COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/app /usr/local/bin/app

USER ${USER}

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["app"]
```

This will use a local Docker-managed cache for `sccache`. You can also use remote
storage like S3. Here is a modified example using S3 as a storage backend:

```dockerfile
### PLANNER STAGE ###
FROM frechetta93/rust-build-base:latest AS planner

# copy the source code into the stage and run `cargo chef prepare` to generate a
# recipe.json file with the project skeleton. This will be used in the next stage to
# compile the dependencies separately from the application code.
# note that we are utilizing two caches:
#   - the cargo registry cache, which caches downloaded dependencies source code
#   - the sccache cache, which caches compiled dependencies
COPY . .
RUN --mount=type=cache,target=$CARGO_HOME/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo chef prepare --recipe-path recipe.json

### BUILDER STAGE ###
FROM frechetta93/rust-build-base:latest AS builder

ARG SCCACHE_BUCKET SCCACHE_REGION

# copy the recipe.json file from the planner stage and run `cargo chef cook` to compile
# the dependencies. If the dependencies don't change between builds, this cached layer
# will be used. Otherwise, sccache will be used.
COPY --from=planner /app/recipe.json recipe.json
RUN --mount=type=cache,target=$CARGO_HOME/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    --mount=type=secret,id=AWS_ACCESS_KEY_ID,env=AWS_ACCESS_KEY_ID \
    --mount=type=secret,id=AWS_SECRET_ACCESS_KEY,env=AWS_SECRET_ACCESS_KEY \
    cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json

# copy the source code into the stage and build the application.
COPY ..

RUN --mount=type=cache,target=$CARGO_HOME/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    --mount=type=secret,id=AWS_ACCESS_KEY_ID,env=AWS_ACCESS_KEY_ID \
    --mount=type=secret,id=AWS_SECRET_ACCESS_KEY,env=AWS_SECRET_ACCESS_KEY \
    cargo build --release --target x86_64-unknown-linux-musl --bin app

### FINAL IMAGE ###
FROM alpine:3.23

ARG USER=app

RUN apk add dumb-init && \
    addgroup -S ${USER} && \
    adduser -S -H ${USER} ${USER}

COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/app /usr/local/bin/app

USER ${USER}

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["app"]
```

To run (assuming you have `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment
variables set):

```
docker build \
    --build-arg SCCACHE_BUCKET=$MY_BUCKET \
    --build-arg SCCACHE_BUCKET=$MY_REGION \
    --secret id=AWS_ACCESS_KEY_ID \
    --secret id=AWS_SECRET_ACCESS_KEY \
    .
```
