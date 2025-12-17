# ONNX Runtime with RKNPU Support

Build ONNX Runtime with Rockchip NPU (RKNPU) execution provider for ARM64 devices like RK3588.

## Features

- ARM64/aarch64 optimized build
- RKNPU execution provider for Rockchip NPU acceleration
- Multi-stage Docker build for minimal runtime image
- Pre-built Python wheels included in final image
- GitHub Actions CI/CD for automated builds

## Quick Start

### Build Locally

```bash
docker build -f Dockerfile.rk3588 -t onnxruntime-rknpu:arm64 .
```

### Extract Wheel

```bash
# Create container from image
docker create --name extract onnxruntime-rknpu:arm64

# Copy wheel to current directory
docker cp extract:/out/. ./wheels/

# Clean up
docker rm extract

# Install wheel
pip3 install wheels/onnxruntime-*.whl
```

### Use Pre-built Image (GitHub Container Registry)

```bash
# Pull the latest image
docker pull ghcr.io/<your-username>/onnxruntime-rknpu:latest

# Extract wheel
docker create --name extract ghcr.io/<your-username>/onnxruntime-rknpu:latest
docker cp extract:/out/. ./wheels/
docker rm extract
```

## GitHub Actions

This repository includes two workflows:

### 1. Build Workflow (`.github/workflows/build-docker.yml`)

Triggers on:
- Push to main/master/develop branches
- Pull requests
- Manual dispatch

Builds the Docker image and uploads wheel artifacts.

### 2. Release Workflow (`.github/workflows/release.yml`)

Triggers on:
- GitHub releases
- Manual dispatch with version tag

Builds and publishes:
- Tagged Docker image to GitHub Container Registry
- Python wheel as release asset

## Configuration

### Environment Variables

Set in `install_onnxruntime_rknpu_arm.sh`:

- `BUILD_TYPE`: CMake build type (default: `MinSizeRel`)
- `BUILD_DIR`: Build directory name (default: `build_rknpu`)
- `BUILD_WHEEL`: Build Python wheel (default: `1`)

### Docker Build Arguments

```bash
docker build \
  --build-arg BUILD_TYPE=Release \
  -f Dockerfile.rk3588 \
  -t onnxruntime-rknpu:arm64 .
```

## Requirements

- Docker with BuildKit support
- For cross-compilation: QEMU and `docker buildx`
- For GitHub Actions: Repository secrets configured

## Target Devices

- Rockchip RK3588
- Other ARM64 devices with RKNPU support

## License

Follow ONNX Runtime and RKNN Toolkit licensing terms.
