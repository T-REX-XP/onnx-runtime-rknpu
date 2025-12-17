#!/usr/bin/env bash
# Build helper with multiple strategies

set -e

show_help() {
    cat << EOF
ONNX Runtime RKNPU Build Helper

Usage: ./build.sh [OPTION]

Options:
    volume      Build with volume mounts (FASTEST, no 3GB upload!)
                Sources mounted directly from host
    
    local       Use COPY from local sources (faster than docker)
                Runs prepare_sources.sh first
    
    docker      Standard Docker build (downloads each time)
    
    extract     Extract wheel from built image/container
    
    clean       Remove sources/ and build artifacts
    
    help        Show this help

Examples:
    ./build.sh volume     # Build with mounted sources (recommended!)
    ./build.sh extract    # Extract wheel after build
    ./build.sh clean      # Clean everything

EOF
}

case "${1:-help}" in
    volume)
        echo "==> Building with volume-mounted sources (zero build context overhead)..."
        ./prepare_sources.sh
        
        # Create output directory
        mkdir -p "$PWD/out"
        
        # Build lightweight builder image (< 10MB context)
        docker build -f Dockerfile.rk3588.build --target builder -t onnxruntime-builder:arm64 .
        
        # Run build with sources mounted from host
        docker run --rm \
            -v "$PWD/sources/rknpu_ddk:/workspace/rknpu_ddk:ro" \
            -v "$PWD/sources/onnxruntime:/workspace/onnxruntime" \
            -v "$PWD/out:/out" \
            -v onnx-ccache:/ccache \
            -e OUTPUT_DIR=/out \
            -e CCACHE_DIR=/ccache \
            --name onnx-build \
            onnxruntime-builder:arm64
        
        echo "==> Build complete! Wheels in ./out/"
        ls -lh ./out/*.whl 2>/dev/null || echo "Checking ./out/Linux/MinSizeRel/dist/"
        ls -lh ./out/Linux/MinSizeRel/dist/*.whl 2>/dev/null || true
        ;;
    
    local)
        echo "==> Building with COPY from local sources..."
        ./prepare_sources.sh
        docker build -f Dockerfile.rk3588.local -t onnxruntime-rknpu:arm64 .
        echo "==> Build complete! Run './build.sh extract' to get the wheel"
        ;;
    
    docker)
        echo "==> Building with standard Dockerfile (will download sources)..."
        docker build -f Dockerfile.rk3588 -t onnxruntime-rknpu:arm64 .
        ;;
    
    compose)
        echo "==> Building with docker-compose..."
        ./prepare_sources.sh
        docker-compose build ort-rknpu-local
        ;;
    
    extract)
        echo "==> Extracting wheel from image..."
        mkdir -p wheels
        docker create --name onnx-extract onnxruntime-rknpu:arm64 || true
        docker cp onnx-extract:/out/. ./wheels/
        docker rm onnx-extract
        echo "==> Wheel extracted to ./wheels/"
        ls -lh ./wheels/*.whl
        ;;
    
    clean)
        echo "==> Cleaning sources and build artifacts..."
        rm -rf sources/ wheels/
        docker-compose down -v || true
        echo "==> Cleaned"
        ;;
    
    help|*)
        show_help
        ;;
esac
