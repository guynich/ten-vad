#!/bin/bash
#
#  Copyright © 2025 Agora
#  This file is part of TEN Framework, an open source project.
#  Licensed under the Apache License, Version 2.0, with certain conditions.
#  Refer to the "LICENSE" file in the root directory for more information.
#
# Simple CMake build script for TEN VAD Python bindings

set -e

echo "🔨 Building TEN VAD Python bindings (CMake)..."

# Check prerequisites
if ! command -v cmake &> /dev/null; then
    echo "CMake not found. Install with: sudo apt install cmake"
    exit 1
fi

# Create virtual environment if not in one
if [[ -z "${VIRTUAL_ENV:-}" ]]; then
    if [[ ! -d "venv" ]]; then
        echo "Creating virtual environment..."
        python3 -m venv venv
    fi
    echo "Activating virtual environment..."
    source venv/bin/activate
fi

# Install pybind11 if needed
echo "Installing pybind11 and numpy..."
pip install -q pybind11 numpy

# Create ONNX model symlink
if [[ ! -e "onnx_model" ]]; then
    echo "Creating ONNX model symlink..."
    ln -sf ../src/onnx_model .
fi

# Build with CMake
echo "Building with CMake..."
rm -rf build-python
mkdir build-python
cd build-python
cp ../CMakeLists-python.txt ./CMakeLists.txt
cmake .
make -j$(nproc)

# Copy module to parent directory
cp ten_vad_python*.so ..
cd ..

echo "Build complete!"
echo "Test with: python3 -c 'import ten_vad_python; print(\"Success!\")'"
echo "Run demo with numpy: python3 ten_vad_demo.py ../examples/s0724-s0730.wav output.txt"
