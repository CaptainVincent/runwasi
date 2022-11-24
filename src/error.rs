#[cfg(feature = "wasmedge")]
use anyhow;
use containerd_shim_wasm::sandbox::error;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum WasmRuntimeError {
    #[error("{0}")]
    Error(#[from] error::Error),
    #[cfg(feature = "wasmedge")]
    #[error("{0}")]
    AnyError(#[from] anyhow::Error),
    #[cfg(feature = "wasmedge")]
    #[error("{0}")]
    Wasmedge(#[from] Box<wasmedge_types::error::WasmEdgeError>),
    #[cfg(feature = "wasmtime")]
    #[error("{0}")]
    Wasi(#[from] wasmtime_wasi::Error),
    #[cfg(feature = "wasmtime")]
    #[error("{0}")]
    WasiCommonStringArray(#[from] wasi_common::StringArrayError),
}
