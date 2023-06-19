FROM --platform=$BUILDPLATFORM rust:1.64 AS buildbase
RUN rustup target add wasm32-wasi
WORKDIR /src

FROM --platform=$BUILDPLATFORM buildbase AS build
COPY ../wasinn/pytorch-mobilenet-image/rust /src
RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index \
    cargo build --target wasm32-wasi --release

FROM scratch AS wasinn
ENTRYPOINT [ "wasmedge-wasinn-example-mobilenet-image.wasm" ]
COPY --link --from=build /src/target/wasm32-wasi/release/wasmedge-wasinn-example-mobilenet-image.wasm  wasmedge-wasinn-example-mobilenet-image.wasm
