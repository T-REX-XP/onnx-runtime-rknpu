#!/usr/bin/env bash
set -e

SOURCES_DIR="./sources"

echo "==> Preparing source repositories in $SOURCES_DIR"

mkdir -p "$SOURCES_DIR"
cd "$SOURCES_DIR"

# Clone or update rknn-toolkit2
if [ -d "rknn-toolkit2/.git" ]; then
    echo "==> Updating rknn-toolkit2..."
    cd rknn-toolkit2
    git pull
    cd ..
else
    echo "==> Cloning rknn-toolkit2..."
    git clone --depth 1 https://github.com/rockchip-linux/rknn-toolkit2.git
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
