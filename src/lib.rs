#![feature(stmt_expr_attributes)]

pub mod error;
pub mod runtime_utils;
#[cfg(feature = "wasmedge")]
pub mod wasmedge;
#[cfg(feature = "wasmtime")]
pub mod wasmtime;

#[cfg(feature = "wasmedge")]
#[macro_use]
extern crate lazy_static;
