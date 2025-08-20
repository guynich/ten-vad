#!/bin/bash
#
#  Copyright © 2025 Agora
#  This file is part of TEN Framework, an open source project.
#  Licensed under the Apache License, Version 2.0, with certain conditions.
#  Refer to the "LICENSE" file in the root directory for more information.
#
# Automated build script for the TEN VAD library using pybind11.
#
set -euo pipefail

echo "TEN VAD Python Bindings Build Script"
echo "===================================="

# Detect architecture
SYSTEM_ARCH=$(uname -m)
echo "Detected architecture: $SYSTEM_ARCH"

# Set ONNX Runtime path based on architecture
case "$SYSTEM_ARCH" in
    "x86_64")
        DEFAULT_ORT_PATH="$HOME/onnxruntime-linux-x64-1.22.0"
        ;;
    "aarch64" | "arm64")
        DEFAULT_ORT_PATH="$HOME/onnxruntime-linux-aarch64-1.22.0"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $SYSTEM_ARCH" >&2
        echo "Supported architectures: x86_64, aarch64" >&2
        exit 1
        ;;
esac

# Parse command line arguments
ORT_ROOT="$DEFAULT_ORT_PATH"
BUILD_METHOD="setuptools"  # or "cmake"
SKIP_DEPS="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --ort-path)
            ORT_ROOT="$2"
            shift 2
            ;;
        --cmake)
            BUILD_METHOD="cmake"
            shift
            ;;
        --skip-deps)
            SKIP_DEPS="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Automatically builds TEN VAD Python bindings with:"
            echo "  - Virtual environment creation (if not already in one)"
            echo "  - Architecture detection and correct ONNX Runtime path"
            echo "  - Dependency installation"
            echo "  - ONNX model symlink creation"
            echo "  - Extension compilation and testing"
            echo ""
            echo "Options:"
            echo "  --ort-path PATH    Path to ONNX Runtime (default: auto-detect)"
            echo "  --cmake           Use CMake build instead of setuptools"
            echo "  --skip-deps       Skip dependency installation (assume already installed)"
            echo "  --help            Show this help message"
            echo ""
            echo "Default ONNX Runtime path for $SYSTEM_ARCH: $DEFAULT_ORT_PATH"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

echo "Using ONNX Runtime path: $ORT_ROOT"
echo "Build method: $BUILD_METHOD"

# Verify ONNX Runtime exists
if [[ ! -d "$ORT_ROOT" || ! -d "$ORT_ROOT/lib" || ! -d "$ORT_ROOT/include" ]]; then
    echo "ERROR: Invalid ONNX Runtime path: $ORT_ROOT" >&2
    echo "Expected structure:" >&2
    echo "  $ORT_ROOT/lib/" >&2
    echo "  $ORT_ROOT/include/" >&2
    echo "" >&2
    echo "For $SYSTEM_ARCH, you can download from:" >&2
    case "$SYSTEM_ARCH" in
        "x86_64")
            echo "  https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-x64-1.22.0.tgz"
            ;;
        "aarch64" | "arm64")
            echo "  https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-aarch64-1.22.0.tgz"
            ;;
    esac
    exit 1
fi

# Check if Python and required packages are available
echo ""
echo "Checking Python environment..."
python3 --version || { echo "ERROR: Python 3 not found"; exit 1; }

# Check if we're in a virtual environment
if [[ "${VIRTUAL_ENV:-}" != "" ]]; then
    echo "Virtual environment detected: $VIRTUAL_ENV"
    PYTHON_CMD="python"
    PIP_CMD="pip"
    PIP_INSTALL_FLAGS=""  # No flags needed in virtual environment
else
    echo "No virtual environment detected"
    echo "Creating virtual environment for TEN VAD..."

    # Check if python3-venv is available
    if ! python3 -m venv --help >/dev/null 2>&1; then
        echo "ERROR: python3-venv not available. Please install it:"
        echo "  sudo apt update && sudo apt install python3-venv"
        exit 1
    fi

    # Create virtual environment if it doesn't exist
    if [[ ! -d "venv_tenvad" ]]; then
        python3 -m venv venv_tenvad
        echo "Created virtual environment: venv_tenvad"
    fi

    # Activate virtual environment
    source venv_tenvad/bin/activate
    echo "Activated virtual environment: $(pwd)/venv_tenvad"

    PYTHON_CMD="python3"
    PIP_CMD="pip"
    PIP_INSTALL_FLAGS=""  # No flags needed in virtual environment
fi

# Check and install requirements
if [[ "$SKIP_DEPS" == "true" ]]; then
    echo ""
    echo "Skipping dependency installation (--skip-deps specified)"
else
    echo ""
    echo "Checking Python requirements..."
    echo "Using pip command: $PIP_CMD"

    # Check if required packages are already installed
    MISSING_PACKAGES=""
    for pkg in numpy pybind11 setuptools wheel; do
        if ! $PYTHON_CMD -c "import $pkg" 2>/dev/null; then
            MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
        fi
    done

    if [[ "$MISSING_PACKAGES" != "" ]]; then
        echo "Installing missing packages:$MISSING_PACKAGES"

        # Upgrade pip first to avoid issues
        $PIP_CMD install --upgrade pip

        # Install requirements
        $PIP_CMD install $PIP_INSTALL_FLAGS -r requirements.txt
    else
        echo "All required packages are already installed"
    fi
fi

# Ensure ONNX model symlink exists
if [[ ! -e "onnx_model" ]]; then
    echo "Creating ONNX model symlink..."
    ln -sf ../src/onnx_model .
fi

# Build the extension
echo ""
echo "Building TEN VAD Python extension..."

if [[ "$BUILD_METHOD" == "cmake" ]]; then
    # CMake build
    echo "Using CMake build method"
    BUILD_DIR="build"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Check if CMake is available
    if ! command -v cmake &> /dev/null; then
        echo "ERROR: CMake not found. Please install it:"
        echo "  sudo apt update && sudo apt install cmake"
        exit 1
    fi

    # Copy the Python CMakeLists file and configure
    cp ../CMakeLists_python.txt ./CMakeLists.txt
    cmake . -DORT_ROOT="$ORT_ROOT"
    make -j$(nproc)

    # Copy the built module back
    cp ten_vad_python*.so ../
    cd ..
    echo "Built module: $(ls ten_vad_python*.so)"

else
    # Setuptools build
    echo "Using setuptools build method"
    $PYTHON_CMD setup.py build_ext --inplace
    echo "Built module: $(ls ten_vad_python*.so)"
fi

# Test the module
echo ""
echo "Testing the module..."
$PYTHON_CMD -c "
import ten_vad_python
print(f'TEN VAD Python module loaded successfully!')
print(f'Version: {ten_vad_python.get_version()}')

# Quick functionality test
vad = ten_vad_python.TenVAD(256, 0.5)
print(f'VAD instance created: hop_size={vad.get_hop_size()}, threshold={vad.get_threshold()}')
print('Basic functionality test passed!')
"

echo ""
echo "Build completed successfully!"
echo ""
echo "Usage examples:"
echo "  $PYTHON_CMD vad_demo.py ../examples/s0724-s0730.wav output.txt"
echo "  $PYTHON_CMD vad_demo.py audio.wav results.txt --threshold 0.6"
echo "  $PYTHON_CMD vad_demo.py audio.wav results.txt --frame-demo"
