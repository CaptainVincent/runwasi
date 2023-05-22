### 0.2.0 (2023-05-15)

Breaking changes:

* Updated the WasmEdge shared library dependency to version `0.12.1`
* Updated the wasmedge-sdk dependency to version `0.8.1`
* Default async feature is not supported now.

Features:

* Introducing a new installation workflow for wasmedge-shim from a DockerHub image
* Supporting automatic detection of plugins

Comming Soon:
* Binding folder to wasm runtime as `readonly` through the `ro` flag.
  1. The flag is already passed from runwasi, but it can only be enabled in wasmedge core after the next release is completed.
  2. And there is a limitation in WASI preview1 where the access rights do not follow to POSIX permissions. As a result, if you examine the metadata of a file descriptor, the read-only permissions will not accurately reflect the actual permissions for WASI.

Documentations:

* Add ChangeLog.md
* Add an [Experimental](docs/experimental.md) page introduce new features.
