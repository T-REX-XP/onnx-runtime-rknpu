#!/usr/bin/env bash
set -e

SRC_ROOT=/workspace/src
RKNPU_REPO=https://github.com/airockchip/rknpu_ddk.git
ORT_REPO=https://github.com/microsoft/onnxruntime.git
BUILD_TYPE=${BUILD_TYPE:-MinSizeRel}
BUILD_DIR=${BUILD_DIR:-build_rknpu}
BUILD_WHEEL=${BUILD_WHEEL:-1}

mkdir -p "$SRC_ROOT"
cd /workspace

# migrated to rknpu_ddk

### rknpu_ddk is required by official RKNPU EP docs
cd /workspace/rknpu_ddk || { echo "ERROR: /workspace/rknpu_ddk not found"; exit 1; }

# Locate librknpu_ddk.so and headers
LIB_SO=$(find . -type f -name "librknpu_ddk.so" | head -n1)
HDR_DIR=$(dirname "$(find . -type f -name "rknpu_pub.h" | head -n1)")

if [ -z "$LIB_SO" ]; then
  echo "ERROR: librknpu_ddk.so not found in rknpu_ddk"
  exit 1
fi

cp "$LIB_SO" /usr/lib/

if [ -n "$HDR_DIR" ]; then
  mkdir -p /usr/include/rknpu
  cp "$HDR_DIR"/*.h /usr/include/rknpu/
else
  echo "WARN: rknpu_pub.h not found; ensure correct rknpu_ddk version"
fi
ldconfig

export RKNPU_DDK_PATH="/workspace/rknpu_ddk"

# Detect number of CPU cores and set parallel jobs
NUM_JOBS=${NUM_JOBS:-$(nproc 2>/dev/null || echo 4)}
# Use most cores, leave one or two free to avoid system freeze
NUM_JOBS=$((NUM_JOBS > 2 ? NUM_JOBS - 1 : NUM_JOBS))
export NUM_JOBS

echo "Building with $NUM_JOBS parallel jobs"

# Enable ccache if available
if command -v ccache >/dev/null 2>&1; then
  export CMAKE_C_COMPILER_LAUNCHER=ccache
  export CMAKE_CXX_COMPILER_LAUNCHER=ccache
  ccache -z  # clear stats
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

CM_EXTRA_DEFINES="RKNPU_DDK_PATH=$RKNPU_DDK_PATH;onnxruntime_ENABLE_CPUINFO=OFF"

# Disable treating warnings as errors (RKNPU EP code has ABI warnings)
CM_EXTRA_DEFINES="$CM_EXTRA_DEFINES;CMAKE_CXX_FLAGS=-Wno-psabi;COMPILE_NO_WARING_AS_ERROR=ON"

# Optional: toolchain and custom protoc if provided
if [ -n "$CMAKE_TOOLCHAIN_FILE" ]; then
  CM_EXTRA_DEFINES="$CM_EXTRA_DEFINES;CMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"
fi
if [ -n "$ONNX_CUSTOM_PROTOC_EXECUTABLE" ]; then
  CM_EXTRA_DEFINES="$CM_EXTRA_DEFINES;ONNX_CUSTOM_PROTOC_EXECUTABLE=$ONNX_CUSTOM_PROTOC_EXECUTABLE"
fi

BUILD_CMD=(./build.sh
  --allow_running_as_root
  --use_rknpu
  --parallel "$NUM_JOBS"
  --build_shared_lib
  --build_dir "$BUILD_DIR"
  --config "$BUILD_TYPE"
  --skip_submodule_sync
  --skip_tests
  --compile_no_warning_as_error
  --cmake_extra_defines "$CM_EXTRA_DEFINES"
)

if [ "$BUILD_WHEEL" = "1" ]; then
  BUILD_CMD+=(--build_wheel)
fi

"${BUILD_CMD[@]}"

# Show ccache stats after build
if command -v ccache >/dev/null 2>&1; then
  echo "=== ccache stats after build ==="
  ccache -s || true
fi

# Copy outputs to OUTPUT_DIR if set
if [ -n "$OUTPUT_DIR" ] && [ -d "$BUILD_DIR/Linux/$BUILD_TYPE/dist" ]; then
  echo "Copying wheels to $OUTPUT_DIR"
  cp -v "$BUILD_DIR/Linux/$BUILD_TYPE/dist"/*.whl "$OUTPUT_DIR/" || true
fi

echo "=== Build complete ==="
