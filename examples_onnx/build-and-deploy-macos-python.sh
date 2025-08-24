#!/bin/bash
#
#  Copyright © 2025 Agora
#  This file is part of TEN Framework, an open source project.
#  Licensed under the Apache License, Version 2.0, with certain conditions.
#  Refer to the "LICENSE" file in the root directory for more information.
#
# Simple CMake build script for TEN VAD Python bindings on macOS.

set -e

# Parse --ort-path argument (optional)
ORT_ROOT=""
if [[ "$#" -ge 2 && "$1" == "--ort-path" ]]; then
    ORT_ROOT="$2"
    shift 2

    if [[ ! -d "$ORT_ROOT" || ! -d "$ORT_ROOT/lib" || ! -d "$ORT_ROOT/include" ]]; then
        echo "invalid onnxruntime library path: $ORT_ROOT" >&2
        exit 1
    fi
    echo "Using ONNX Runtime path: $ORT_ROOT"
elif [[ "$#" -ge 1 && "$1" == "--help" ]]; then
    echo "usage: $0 [--ort-path <path_to_onnxruntime>]" >&2
    echo "  --ort-path: Optional path to ONNX Runtime installation" >&2
    echo "              If not provided, attempts auto-detection based on" >&2
    echo "              architecture and v1.22.0" >&2
    exit 0
fi

echo "Building TEN VAD Python bindings (CMake)..."

# Check prerequisites
if ! command -v cmake &> /dev/null; then
    echo "CMake not found. Install with: brew install cmake"
    exit 1
fi

# Create build directory
rm -rf build-macos-python
mkdir build-macos-python

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv build-macos-python/venv

# Activate virtual environment
echo "Activating virtual environment..."
source build-macos-python/venv/bin/activate

# Install pybind11 if needed
echo "Installing pybind11 and numpy..."
pip install -q pybind11 numpy

# Setup build directory
cd build-macos-python
cp ../CMakeLists-python.txt ./CMakeLists.txt

# Create ONNX model symlink in build directory
if [[ ! -e "onnx_model" ]]; then
    echo "Creating ONNX model symlink..."
    ln -sf ../../src/onnx_model .
fi

# Build with CMake
echo "Building with CMake..."
if [[ -n "$ORT_ROOT" ]]; then
    # Detect architecture for macOS
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        CMAKE_ARCH="x86_64"
    else
        CMAKE_ARCH="arm64"
    fi

    # Use the virtual environment's Python for consistency
    VENV_PYTHON=$(which python3)
    echo "Using Python: $VENV_PYTHON"

    cmake . \
        -DORT_ROOT="$ORT_ROOT" \
        -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
        -DCMAKE_C_COMPILER=/usr/bin/clang \
        -DCMAKE_OSX_ARCHITECTURES=${CMAKE_ARCH} \
        -DCMAKE_BUILD_TYPE=Release \
        -DPython_EXECUTABLE="$VENV_PYTHON"

    cmake --build . --config Release
else
        # Auto-detect architecture and try default ONNX Runtime path
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        ONNX_ARCH="x86_64"
        CMAKE_ARCH="x86_64"
    else
        ONNX_ARCH="arm64"
        CMAKE_ARCH="arm64"
    fi

    ONNX_VER="1.22.0"
    ONNX_DEFAULT_PATH="$HOME/onnxruntime-osx-$ONNX_ARCH-$ONNX_VER"

        if [[ -d "$ONNX_DEFAULT_PATH" ]]; then
        echo "Auto-detected ONNX Runtime at: $ONNX_DEFAULT_PATH"

        # Use the virtual environment's Python for consistency
        VENV_PYTHON=$(which python3)
        echo "Using Python: $VENV_PYTHON"

        cmake . \
            -DORT_ROOT="$ONNX_DEFAULT_PATH" \
            -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
            -DCMAKE_C_COMPILER=/usr/bin/clang \
            -DCMAKE_OSX_ARCHITECTURES=${CMAKE_ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DPython_EXECUTABLE="$VENV_PYTHON"

        cmake --build . --config Release

        # Set ORT_ROOT for later use in DYLD_LIBRARY_PATH
        ORT_ROOT="$ONNX_DEFAULT_PATH"
    else
        echo "ONNX Runtime not found at default location: $ONNX_DEFAULT_PATH"
        echo "Please download ONNX Runtime and use --ort-path option"
        echo ""
        echo "Download ONNX Runtime for macOS:"
        if [[ "$ARCH" == "x86_64" ]]; then
            echo "  curl -OL https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VER}/onnxruntime-osx-x86_64-${ONNX_VER}.tgz"
        else
            echo "  curl -OL https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VER}/onnxruntime-osx-arm64-${ONNX_VER}.tgz"
        fi
        echo "  tar -xzf onnxruntime-osx-*-${ONNX_VER}.tgz"
        echo "  rm onnxruntime-osx-*-${ONNX_VER}.tgz"
        echo ""
        echo "Then run: $0 --ort-path ~/onnxruntime-osx-$ONNX_ARCH-$ONNX_VER"
        exit 1
    fi
fi

# Move module to lib directory within build-macos-python
mkdir -p lib
# Find and move the Python extension, wherever it was built
find . -name "ten_vad_python*.so" -not -path "./lib/*" -exec mv {} lib/ \;

# Verify the module is in the right place
if ls lib/ten_vad_python*.so 1> /dev/null 2>&1; then
    echo "Python extension module found in lib/"
    ls -la lib/ten_vad_python*.so
else
    echo "Warning: Python extension module not found in lib/"
    echo "Looking for module in build directory:"
    find . -name "ten_vad_python*.so"
fi

# Copy demo script to build-macos-python for easy testing
cp ../ten_vad_demo.py .

echo "Testing Python import..."
DYLD_LIBRARY_PATH="$ORT_ROOT/lib:$DYLD_LIBRARY_PATH" python3 -c 'import sys; sys.path.insert(0, "lib"); import ten_vad_python; print("Import success!")'

echo "Running demo..."
DYLD_LIBRARY_PATH="$ORT_ROOT/lib:$DYLD_LIBRARY_PATH" python3 ./ten_vad_demo.py ../../examples/s0724-s0730.wav out-python.txt

deactivate
cd ..

echo ""
echo "Build complete!"
echo "All artifacts in: examples_onnx/build-macos-python/"
echo ""
echo "To test the Python extension manually:"
echo "  cd examples_onnx/build-macos-python"
echo "  export DYLD_LIBRARY_PATH=\"$ORT_ROOT/lib:\$DYLD_LIBRARY_PATH\""
echo "  python3 -c 'import sys; sys.path.insert(0, \"lib\"); import ten_vad_python; print(\"Import success!\")'"
echo ""
echo "Note: The DYLD_LIBRARY_PATH must be set to point to the ONNX Runtime lib directory"
