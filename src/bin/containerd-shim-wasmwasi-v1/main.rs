use containerd_shim as shim;
use containerd_shim_wasm::sandbox::ShimCli;
use runwasi::runtime_utils::runtime_check;
#[cfg(feature = "wasmedge")]
use runwasi::wasmedge::instance::Wasi as WasiInstance;
#[cfg(feature = "wasmtime")]
use runwasi::wasmtime::instance::Wasi as WasiInstance;

fn main() {
    runtime_check();
    #[cfg(feature = "wasmedge")]
    shim::run::<ShimCli<WasiInstance, wasmedge_sdk::Vm>>("io.containerd.wasmedge.v1", None);
    #[cfg(feature = "wasmtime")]
    shim::run::<ShimCli<WasiInstance, wasmtime::Engine>>("io.containerd.wasmtime.v1", None);
}
