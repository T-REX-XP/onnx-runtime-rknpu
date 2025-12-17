#!/usr/bin/env bash
set -e

SOURCES_DIR="./sources"

echo "==> Preparing source repositories in $SOURCES_DIR"

mkdir -p "$SOURCES_DIR"
cd "$SOURCES_DIR"

# Clone or update rknpu_ddk (required by official RKNPU EP docs)
if [ -d "rknpu_ddk/.git" ]; then
    echo "==> Updating rknpu_ddk..."
    cd rknpu_ddk
    git pull
    cd ..
else
    echo "==> Cloning rknpu_ddk..."
    git clone --depth 1 https://github.com/airockchip/rknpu_ddk.git
fi

# Clone or update onnxruntime
if [ -d "onnxruntime/.git" ]; then
    echo "==> Updating onnxruntime..."
    cd onnxruntime
    git pull
    git submodule update --init --recursive --depth 1
    cd ..
else
    echo "==> Cloning onnxruntime..."
    git clone --depth 1 --recursive --shallow-submodules \
        https://github.com/microsoft/onnxruntime.git
fi

cd ..
echo "==> Sources ready in $SOURCES_DIR"
echo "==> Run: docker build -f Dockerfile.rk3588.local -t onnxruntime-rknpu:arm64 ."
