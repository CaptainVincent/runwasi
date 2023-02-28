FROM rust:1.64 AS build
RUN rustup target add wasm32-wasi
COPY . /src
WORKDIR /src
RUN cargo build --target wasm32-wasi --release

FROM vincent2nd/runwasi-installable:latest AS demo
ENTRYPOINT [ "app.wasm" ]
COPY --from=build /src/target/wasm32-wasi/release/wasmedge-wasinn-example-mobilenet-image.wasm /app.wasm