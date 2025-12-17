#!/usr/bin/env bash
set -e

SRC_ROOT=/workspace/src
RKNN_REPO=https://github.com/rockchip-linux/rknn-toolkit2.git
ORT_REPO=https://github.com/microsoft/onnxruntime.git
BUILD_TYPE=${BUILD_TYPE:-MinSizeRel}
BUILD_DIR=${BUILD_DIR:-build_rknpu}
BUILD_WHEEL=${BUILD_WHEEL:-1}

mkdir -p "$SRC_ROOT"
cd /workspace

# rknn-toolkit2 cloned in Dockerfile to /workspace/rknn-toolkit2
cd /workspace/rknn-toolkit2

RUNTIME_BASE=""
if [ -d rknpu2/runtime/RK3588/Linux/librknn_api ]; then
  RUNTIME_BASE="rknpu2/runtime/RK3588/Linux"
elif [ -d rknpu2/runtime/Linux/librknn_api ]; then
  RUNTIME_BASE="rknpu2/runtime/Linux"
fi

if [ -z "$RUNTIME_BASE" ]; then
  echo "ERROR: Could not find RK3588 runtime in rknn-toolkit2."
  exit 1
fi

LIB_DIR=${RUNTIME_BASE}/librknn_api/aarch64
HDR_DIR=${RUNTIME_BASE}/librknn_api/include

if [ ! -f "$LIB_DIR/librknnrt.so" ] && [ ! -f "$LIB_DIR/librknpu_ddk.so" ]; then
  echo "ERROR: No RKNN runtime .so in $LIB_DIR"
  exit 1
fi

if [ -f "$LIB_DIR/librknnrt.so" ]; then
  cp "$LIB_DIR/librknnrt.so" /usr/lib/
else
  cp "$LIB_DIR/librknpu_ddk.so" /usr/lib/
fi

mkdir -p /usr/include/rknn
if [ -d "$HDR_DIR" ]; then
  cp "$HDR_DIR"/* /usr/include/rknn/
fi
ldconfig

export RKNPU_DDK_PATH="/workspace/rknn-toolkit2/rknpu2"

# Enable ccache if available
if command -v ccache >/dev/null 2>&1; then
  export CMAKE_C_COMPILER_LAUNCHER=ccache
  export CMAKE_CXX_COMPILER_LAUNCHER=ccache
  ccache -s || true
fi

# Adjust CMakeLists.txt to accept CMake 3.25+
if [ -f /workspace/onnxruntime/CMakeLists.txt ]; then
  sed -i 's/cmake_minimum_required(VERSION 3\.28)/cmake_minimum_required(VERSION 3.25)/' /workspace/onnxruntime/CMakeLists.txt
else
  echo "WARN: /workspace/onnxruntime/CMakeLists.txt not found — skipping CMake minimum version patch"
fi

if [ -f /workspace/onnxruntime/cmake/CMakeLists.txt ]; then
  sed -i 's/cmake_minimum_required(VERSION 3\.28)/cmake_minimum_required(VERSION 3.25)/' /workspace/onnxruntime/cmake/CMakeLists.txt
else
  echo "WARN: /workspace/onnxruntime/cmake/CMakeLists.txt not found — skipping CMake minimum version patch"
fi

# onnxruntime cloned in Dockerfile to /workspace/onnxruntime
cd /workspace/onnxruntime

CM_EXTRA_DEFINES="RKNPU_DDK_PATH=$RKNPU_DDK_PATH onnxruntime_ENABLE_CPUINFO=OFF"

BUILD_CMD=(./build.sh
  --allow_running_as_root
  --use_rknpu
  --parallel
  --build_shared_lib
  --build_dir "$BUILD_DIR"
  --config "$BUILD_TYPE"
  --skip_submodule_sync
  --skip_tests
  --cmake_extra_defines "$CM_EXTRA_DEFINES"
)

if [ "$BUILD_WHEEL" = "1" ]; then
  BUILD_CMD+=(--build_wheel)
fi

"${BUILD_CMD[@]}"
