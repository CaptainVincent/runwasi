# Runwasi with WasmEdge Advancements

> ### Announcement  
> This repository is not the official version of [Runwasi](https://github.com/containerd/runwasi).  Its purpose is solely to showcase the functionalities of Runwasi with [WasmEdge](https://github.com/WasmEdge/WasmEdge) through demonstrations and provide users with quick access to installation package releases. If you are new to Runwasi, I would recommend reading the official [README](https://github.com/containerd/runwasi/blob/main/README.md) first. The following operations and explanations assume that you have a certain level of familiarity to proceed.

## Installation Package Instructions
The current installation process for the latest release is based on **[containerd managing opt](https://github.com/containerd/containerd/blob/main/docs/managed-opt.md)**. We maintain installable images in several Docker repositories. Here, we'll briefly explain how to access them.

### [runwasi-wasmedge](https://hub.docker.com/r/vincent2nd/runwasi-wasmedge)

Maintain an image with only the shim and essential libraries, currently providing a `latest` tag image for regular updates and a `preview` image for pre-release demo, specifically for showcasing the functionality required by llama2.

- latest
- preview

### [runwasi-wasmedge-plugin](https://hub.docker.com/r/vincent2nd/runwasi-wasmedge-plugin)

This is the new plugin functionality we currently support. The installation process for plugins is similar to the one mentioned earlier (shim only), which will be explained in more detail below. The difference lies in the use of tags to differentiate functionality. In general, the naming convention is as follows: 

```
<package>.<plugin>
```

The only exception to this is the addition of the `-preview` postfix, which is used specifically for llama2 demos.

- \<package\>
  - lib : Library only, including plugin and its dependencies.
  - allinone : In addition to the library, it also includes the Wasmedge Shim binary.
- \<plugin\> : suppoted plugin
  - wasi_nn-pytorch
  - wasi_nn-ggml-preview
  - wasm_bpf (TBV)
  - wasmedge_image (TBV)
  - wasmedge_tensorflow (TBV)
  - wasmedge_tensorflowlite (TBV)
  - wasi_crypto (TBV)
  - wasi_nn-tensorflowlite (TBV)
  - wasi_nn-openvino (TBV)


> ### Warning  
> 1. **TBV** means to be verified. It has been pre-packaged, but complete integration tests have not been added yet, so there may be issues during execution.
> 2. This feature is still in progress, and the naming conventions may change at later.

## Instructions

- To install the above packages, you can simply execute the following commands.

```bash
sudo ctr content fetch <docker_img>:<tag>
sudo ctr install <docker_img>:<tag> -l -r
```

- To remove it, you will need to manually delete the files under the specified path (if they exist).

```bash
rm /opt/containerd/lib/*
rm /opt/containerd/bin/*
```

> ### Warning  
> Installation from the `ctr` command will overwrite the default runtime (shim) search path. So, if you want to run the shim build from source, you should first execute the previous command to remove them and then restart `containerd` using the command below.

```bash
sudo systemctl daemon-reload && sudo systemctl restart containerd
```

## Demo

We have prepared three daily run demo actions, including [ctr](https://github.com/CaptainVincent/runwasi/blob/CI/.github/workflows/full-testing.yml), [docker](https://github.com/CaptainVincent/runwasi/blob/CI/.github/workflows/docker-demo.yml), and [llama2](https://github.com/CaptainVincent/runwasi/blob/CI/.github/workflows/llama2.yml) (preview). You can check their usage and current [status](https://github.com/CaptainVincent/runwasi/actions).

## Prebuilt demo image

[Here](https://github.com/CaptainVincent?tab=packages), I have prebuilt demo images available. You can obtain these same images by simply running `make load_demo` and `make load` (official test case) in the root folder. They are generated based on the test cases in this [directory](https://github.com/CaptainVincent/runwasi/tree/CI/demo).
