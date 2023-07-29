# syntax=docker/dockerfile:1

# Make sure to keep in sync with the version in rust-toolchain.toml
ARG RUST_VERSION=1.71

ARG XX_VERSION=1.2.1
ARG WASMEDGE_VERSION=0.13.1

FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx

FROM --platform=$BUILDPLATFORM rust:${RUST_VERSION} AS base
COPY --from=xx / /
RUN apt-get update -y && apt-get install --no-install-recommends -y clang pkg-config dpkg-dev jq

# See https://github.com/tonistiigi/xx/issues/108
RUN sed -i -E 's/xx-clang --setup-target-triple/XX_VENDOR=\$vendor xx-clang --setup-target-triple/' $(which xx-cargo) && \
    sed -i -E 's/\$\(xx-info\)-/\$\(XX_VENDOR=\$vendor xx-info\)-/g' $(which xx-cargo)

FROM base AS build
SHELL ["/bin/bash", "-c"]
ARG BUILD_TAGS TARGETPLATFORM WASMEDGE_VERSION
RUN xx-apt-get install -y gcc g++ libc++6-dev zlib1g
RUN xx-apt-get install -y libsystemd-dev libdbus-1-dev libseccomp-dev
RUN rustup target add $(xx-info march)-unknown-$(xx-info os)-$(xx-info libc)

WORKDIR /build/src
COPY --link crates ./crates
COPY --link benches ./benches
COPY --link Cargo.toml ./
COPY --link Cargo.lock ./
ARG CRATE=""
ARG TARGETOS TARGETARCH TARGETVARIANT
RUN curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- \
        --version ${WASMEDGE_VERSION} \
        --platform $(xx-info os | sed -e 's/\b\(.\)/\u\1/g') \
        --machine $(xx-info march) \
        --path /usr/local

RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index \
    --mount=type=cache,target=/build/src/target,id=runwasi-cargo-build-cache-${TARGETOS}-${TARGETARCH}${TARGETVARIANT} <<EOT
    set -e
    export "CARGO_NET_GIT_FETCH_WITH_CLI=true"
    export RUSTFLAGS='-Clink-arg=-Wl,-rpath,$ORIGIN'
    export "CARGO_TARGET_$(xx-info march | tr '[:lower:]' '[:upper:]' | tr - _)_UNKNOWN_$(xx-info os | tr '[:lower:]' '[:upper:]' | tr - _)_$(xx-info libc | tr '[:lower:]' '[:upper:]' | tr - _)_LINKER=$(xx-info)-gcc"
    export "CC_$(xx-info march | tr '[:lower:]' '[:upper:]' | tr - _)_UNKNOWN_$(xx-info os | tr '[:lower:]' '[:upper:]' | tr - _)_$(xx-info libc | tr '[:lower:]' '[:upper:]' | tr - _)=$(xx-info)-gcc"
    if [ -n "${CRATE}" ]; then
        package="--package=${CRATE}"
    fi
    xx-cargo build --release ${package}
EOT
COPY scripts ./scripts
RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index \
    --mount=type=cache,target=/build/src/target,id=runwasi-cargo-build-cache-${TARGETOS}-${TARGETARCH}${TARGETVARIANT} <<EOT
    set -e
    mkdir /build/bin
    bins="$(scripts/bins.sh ${CRATE} | jq -r 'join(" ")')"
    echo "Copying binaries: ${bins}"
    for bin in ${bins}; do
        cp target/$(xx-info march)-unknown-$(xx-info os)-$(xx-info libc)/release/${bin} /build/bin/${bin}
    done
EOT

FROM build AS build-tar
WORKDIR /build/release
ARG CRATE
ARG TARGETOS TARGETARCH TARGETVARIANT
RUN <<EOF
if [ -n "$(find /build/bin -type f -exec echo {} \;)" ]; then
    tar -C /build/bin -czf "/build/release/${CRATE}-${TARGETOS}-${TARGETARCH}${TARGETVARIANT}.tar.gz" .
fi
EOF

FROM scratch AS release-tar
COPY --link --from=build-tar /build/release/* /

FROM scratch AS release
COPY --link --from=build /build/bin/* /
