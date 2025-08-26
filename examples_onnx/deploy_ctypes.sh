#!/bin/bash
#
#  Copyright © 2025 Agora
#  This file is part of TEN Framework, an open source project.
#  Licensed under the Apache License, Version 2.0, with certain conditions.
#  Refer to the "LICENSE" file in the root directory for more information.
#
# Deploy ctypes VAD implementation to build directories

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Deploying ctypes VAD implementation..."

# Deploy to macOS build directory if it exists
if [ -d "python/build-macos" ]; then
    echo "  → Copying to python/build-macos/"
    cp ten_vad_ctypes.py python/build-macos/
    cp ten_vad_demo_ctypes.py python/build-macos/
    echo "    ✓ Deployed to macOS build directory"
else
    echo "  ⚠ macOS build directory not found: python/build-macos"
fi

# Deploy to Linux build directory if it exists
if [ -d "python/build-linux" ]; then
    echo "  → Copying to python/build-linux/"
    cp ten_vad_ctypes.py python/build-linux/
    cp ten_vad_demo_ctypes.py python/build-linux/
    echo "    ✓ Deployed to Linux build directory"
else
    echo "  ⚠ Linux build directory not found: python/build-linux"
fi

echo "Deployment complete!"
echo ""
echo "Usage:"
echo "  cd python/build-macos  # or python/build-linux"
echo "  python3 ten_vad_demo_ctypes.py ../../../examples/s0724-s0730.wav out-ctypes.txt"
echo ""
echo "Performance comparison:"
echo "  python3 ten_vad_demo.py ../../../examples/s0724-s0730.wav out-pybind11.txt"
echo "  python3 ten_vad_demo_ctypes.py ../../../examples/s0724-s0730.wav out-ctypes.txt"
