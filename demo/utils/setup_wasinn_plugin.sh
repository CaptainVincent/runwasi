#!/bin/sh -x

# Download PyTorch
if [ ! -d "$PWD/libtorch" ]
then
  export PYTORCH_VERSION="1.8.2"
  curl -s -L -O --remote-name-all https://download.pytorch.org/libtorch/lts/1.8/cpu/libtorch-cxx11-abi-shared-with-deps-${PYTORCH_VERSION}%2Bcpu.zip
  unzip -q "libtorch-cxx11-abi-shared-with-deps-${PYTORCH_VERSION}%2Bcpu.zip"
  rm -f "libtorch-cxx11-abi-shared-with-deps-${PYTORCH_VERSION}%2Bcpu.zip"
  sudo sh -c 'echo "$(pwd)/libtorch/lib" > /etc/ld.so.conf.d/libtorch.conf'
fi

# Download Wasmedge
curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- -v 0.12.1 --plugins wasi_nn-pytorch
sudo -E sh -c 'echo "$HOME/.wasmedge/lib" > /etc/ld.so.conf.d/libwasmedge.conf'

sudo ldconfig
export WASMEDGE_INCLUDE_DIR=$PWD/WasmEdge-0.11.1-Linux/include
export WASMEDGE_LIB_DIR=$PWD/WasmEdge-0.11.1-Linux/lib
export WASMEDGE_PLUGIN_PATH=$PWD/WasmEdge-0.11.1-Linux/lib/wasmedge
