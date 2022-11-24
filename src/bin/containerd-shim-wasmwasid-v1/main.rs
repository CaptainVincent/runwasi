use containerd_shim as shim;
use containerd_shim_wasm::sandbox::manager::Shim;
use runwasi::runtime_utils::runtime_check;

fn main() {
    runtime_check();
    #[cfg(feature = "wasmedge")]
    shim::run::<Shim>("containerd-shim-wasmedged-v1", None);
    #[cfg(feature = "wasmtime")]
    shim::run::<Shim>("containerd-shim-wasmtimed-v1", None);
}
