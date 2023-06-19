# syntax=docker/dockerfile:1

ARG RUST_VERSION=1.63
ARG XX_VERSION=1.1.0

FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx

FROM --platform=$BUILDPLATFORM rust:${RUST_VERSION} AS base
COPY --from=xx / /
RUN apt-get update -y && apt-get install --no-install-recommends -y clang
# Nightly is needed because there are nested workspaces
RUN rustup default nightly

FROM base AS build
SHELL ["/bin/bash", "-c"]
ARG BUILD_TAGS TARGETPLATFORM
ENV WASMEDGE_INCLUDE_DIR=/root/.wasmedge/include
ENV WASMEDGE_LIB_DIR=/root/.wasmedge/lib
ENV LD_LIBRARY_PATH=/root/.wasmedge/lib
RUN xx-apt-get install -y gcc g++ libc++6-dev zlib1g
RUN rustup target add $(xx-info march)-unknown-$(xx-info os)-$(xx-info libc)
RUN <<EOT
    set -ex
    os=$(xx-info os)
    curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- --version=0.12.1 --platform=${os^} --machine=$(xx-info march)
EOT

COPY . .
WORKDIR /

RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index <<EOT
    set -e
    export "CARGO_NET_GIT_FETCH_WITH_CLI=true"
    export "CARGO_TARGET_$(xx-info march | tr '[:lower:]' '[:upper:]' | tr - _)_UNKNOWN_$(xx-info os | tr '[:lower:]' '[:upper:]' | tr - _)_$(xx-info libc | tr '[:lower:]' '[:upper:]' | tr - _)_LINKER=$(xx-info)-gcc"
    export "CC_$(xx-info march | tr '[:lower:]' '[:upper:]' | tr - _)_UNKNOWN_$(xx-info os | tr '[:lower:]' '[:upper:]' | tr - _)_$(xx-info libc | tr '[:lower:]' '[:upper:]' | tr - _)=$(xx-info)-gcc"
    cargo build --release --target=$(xx-info march)-unknown-$(xx-info os)-$(xx-info libc)
    cp target/$(xx-info march)-unknown-$(xx-info os)-$(xx-info libc)/release/containerd-shim-wasmedge-v1 /containerd-shim-wasmedge-v1
EOT

FROM scratch AS release
COPY --link --from=build /containerd-shim-wasmedge-v1 /containerd-shim-wasmedge-v1
COPY --link --from=build /root/.wasmedge/lib/libwasmedge.so.0.0.2 /libwasmedge.so.0.0.2

FROM release
