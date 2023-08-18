use anyhow::{anyhow, Result};
use containerd_shim_wasm::sandbox::oci;
use nix::unistd::{dup, dup2};
use oci_spec::runtime::Spec;

use libc::{STDERR_FILENO, STDIN_FILENO, STDOUT_FILENO};
use libcontainer::workload::{Executor, ExecutorError};
use log::debug;
use nix::mount::{mount, MsFlags};
use std::collections::HashMap;
use std::path::Path;
use std::{os::unix::io::RawFd, path::PathBuf};

use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    params,
    plugin::PluginManager,
    VmBuilder,
};

const EXECUTOR_NAME: &str = "wasmedge";

pub struct WasmEdgeExecutor {
    stdin: Option<RawFd>,
    stdout: Option<RawFd>,
    stderr: Option<RawFd>,
}

impl WasmEdgeExecutor {
    pub fn new(stdin: Option<RawFd>, stdout: Option<RawFd>, stderr: Option<RawFd>) -> Self {
        Self {
            stdin,
            stdout,
            stderr,
        }
    }
}

impl Executor for WasmEdgeExecutor {
    fn exec(&self, spec: &Spec) -> Result<(), ExecutorError> {
        // parse wasi parameters
        let args = oci::get_args(spec);
        if args.is_empty() {
            return Err(ExecutorError::InvalidArg);
        }

        let vm = self
            .prepare(args, spec)
            .map_err(|err| ExecutorError::Other(format!("failed to prepare function: {}", err)))?;

        // TODO: How to get exit code?
        // This was relatively straight forward in go, but wasi and wasmtime are totally separate things in rust
        let (module_name, method) = oci::get_module(spec);
        debug!("running {:?} with method {}", module_name, method);
        match vm.run_func(Some("main"), method, params!()) {
            Ok(_) => std::process::exit(0),
            Err(_) => std::process::exit(137),
        };
    }

    fn can_handle(&self, spec: &Spec) -> bool {
        // check if the entrypoint of the spec is a wasm binary.
        let (module_name, _method) = oci::get_module(spec);
        let module_name = match module_name {
            Some(m) => m,
            None => {
                log::info!("WasmEdge cannot handle this workload, no arguments provided");
                return false;
            }
        };
        let path = PathBuf::from(module_name);

        path.extension()
            .map(|ext| ext.to_ascii_lowercase())
            .is_some_and(|ext| ext == "wasm" || ext == "wat")
    }

    fn name(&self) -> &'static str {
        EXECUTOR_NAME
    }
}

impl WasmEdgeExecutor {
    fn prepare(&self, args: &[String], spec: &Spec) -> anyhow::Result<wasmedge_sdk::Vm> {
        let rootfs_path: &str = oci::get_root(&spec)
            .to_str()
            .expect("Rootfs path contains invalid UTF-8 characters.");
        let envs = env_to_wasi(spec);
        let preopens = genereate_preopen(&spec);
        let config = ConfigBuilder::new(CommonConfigOptions::default())
            .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
            .build()
            .map_err(|err| ExecutorError::Execution(err))?;
        let mut vm = VmBuilder::new()
            .with_config(config)
            .build()
            .map_err(|err| ExecutorError::Execution(err))?;
        let wasi_module = vm
            .wasi_module_mut()
            .ok_or_else(|| anyhow::Error::msg("Not found wasi module"))
            .map_err(|err| ExecutorError::Execution(err.into()))?;
        wasi_module.initialize(
            Some(args.iter().map(|s| s as &str).collect()),
            Some(envs.iter().map(|s| s as &str).collect()),
            Some(preopens.iter().map(|s| s as &str).collect()),
        );

        let (module_name, _) = oci::get_module(spec);
        let module_name = match module_name {
            Some(m) => m,
            None => return Err(anyhow::Error::msg("no module provided cannot load module")),
        };
        let vm = vm
            .register_module_from_file("main", module_name)
            .map_err(|err| ExecutorError::Execution(err))?;
        if let Some(stdin) = self.stdin {
            dup(STDIN_FILENO)?;
            dup2(stdin, STDIN_FILENO)?;
        }
        if let Some(stdout) = self.stdout {
            dup(STDOUT_FILENO)?;
            dup2(stdout, STDOUT_FILENO)?;
        }
        if let Some(stderr) = self.stderr {
            dup(STDERR_FILENO)?;
            dup2(stderr, STDERR_FILENO)?;
        }

        let envs = parse_env(&envs);
        let plugins_on_host_path = envs.get("WASMEDGE_PLUGIN_HOST_PATH");
        let plugins_in_container_path: Option<_> = envs.get("WASMEDGE_PLUGIN_PATH");
        let path: String = match (plugins_on_host_path, plugins_in_container_path) {
            (Some(_), Some(_)) => {
                return Err(anyhow!("Ambiguous to identify plugins path"));
            }
            (Some(host_path), None) => host_path.to_owned(),
            (None, Some(container_path)) => {
                format!("{}/{}", rootfs_path, container_path)
            }
            (None, None) => {
                format!("/opt/containerd/lib")
            }
        };

        // Shadow host's /opt/containerd/lib/
        if Path::new(&path).exists() && path != "/opt/containerd/lib" {
            mount::<str, Path, str, str>(
                Some(path.as_str()),
                Path::new("/opt/containerd/lib"),
                None,
                MsFlags::MS_BIND,
                None,
            )
            .map_err(|err| {
                return anyhow!("Replace dylib from docker base image fail: {}", err);
            })?;
        }

        PluginManager::load(Some(Path::new("/opt/containerd/lib")))?;
        let vm = vm.auto_detect_plugins()?;
        Ok(vm)
    }
}

fn env_to_wasi(spec: &Spec) -> Vec<String> {
    let default = vec![];
    let env = spec
        .process()
        .as_ref()
        .unwrap()
        .env()
        .as_ref()
        .unwrap_or(&default);
    env.to_vec()
}

fn parse_env(envs: &[String]) -> HashMap<String, String> {
    // make NAME=VALUE to HashMap<NAME, VALUE>.
    envs.iter()
        .filter_map(|e| {
            let mut split = e.split('=');

            split.next().map(|key| {
                let value = split.collect::<Vec<&str>>().join("=");
                (key.into(), value)
            })
        })
        .collect()
}

fn genereate_preopen(spec: &Spec) -> Vec<String> {
    let mut preopens: Vec<String> = vec![];
    if let Some(root) = spec.root() {
        if let Some(true) = root.readonly() {
            preopens.push(format!("/:{}:readonly", root.path().to_string_lossy()));
        } else {
            preopens.push(format!("/:{}", root.path().to_string_lossy()));
        }
    }
    if let Some(mounts) = spec.mounts() {
        for mount in mounts {
            if let Some(typ) = mount.typ() {
                if typ == "bind" || typ == "tmpfs" {
                    let path = mount.destination().to_string_lossy();
                    if let Some(options) = mount.options() {
                        if options.contains(&"ro".to_string()) {
                            preopens.push(format!("{}:{}:readonly", path, path));
                        }
                    } else {
                        preopens.push(format!("{}:{}", path, path));
                    }
                }
            }
        }
    }
    return preopens;
}
