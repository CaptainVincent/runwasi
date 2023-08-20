#!/bin/sh

install_libtorch=false
install_wasinn_plugin=false

# Parse command line arguments
while [ $# -gt 0 ]; do
  case "$1" in
  --libtorch)
    install_libtorch=true
    shift
    ;;
  --wasinn-plugin)
    install_wasinn_plugin=true
    shift
    ;;
  *)
    echo "Unknown argument: $1"
    exit 1
    ;;
  esac
done

# Install LibTorch
if [ "$install_libtorch" = true ]; then
  if [ ! -d "$PWD/libtorch" ]; then
    export PYTORCH_VERSION="1.8.2"
    curl -s -L -O --remote-name-all https://download.pytorch.org/libtorch/lts/1.8/cpu/libtorch-cxx11-abi-shared-with-deps-${PYTORCH_VERSION}%2Bcpu.zip
    unzip -q "libtorch-cxx11-abi-shared-with-deps-${PYTORCH_VERSION}%2Bcpu.zip"
    rm -f "libtorch-cxx11-abi-shared-with-deps-${PYTORCH_VERSION}%2Bcpu.zip"
    sudo sh -c 'echo "$(pwd)/libtorch/lib" > /etc/ld.so.conf.d/libtorch.conf'
    sudo ldconfig
  fi
fi

# Install WASINN plugin
if [ "$install_wasinn_plugin" = true ]; then
  if [ ! -f "$PWD/libwasmedgePluginWasiNN.so" ]; then
    curl -sLO https://github.com/WasmEdge/WasmEdge/releases/download/0.13.3/WasmEdge-plugin-wasi_nn-pytorch-0.13.3-ubuntu20.04_x86_64.tar.gz
    tar -zxf WasmEdge-plugin-wasi_nn-pytorch-0.13.3-ubuntu20.04_x86_64.tar.gz
    rm -f WasmEdge-plugin-wasi_nn-pytorch-0.13.3-ubuntu20.04_x86_64.tar.gz
  fi
fi
