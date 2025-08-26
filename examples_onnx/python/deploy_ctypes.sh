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
echo "Deployment complete!"
DEPLOYED=0
# Deploy to macOS build directory if it exists
if [ -d "build-macos" ]; then
    echo "  → Copying to build-macos/"
    cp ten_vad_ctypes.py build-macos/
    cp ten_vad_demo_ctypes.py build-macos/
    echo "    ✓ Deployed to macOS build directory"
    DEPLOYED=1
else
    echo "  ⚠ macOS build directory not found: build-macos"
fi

# Deploy to Linux build directory if it exists
if [ -d "build-linux" ]; then
    echo "  → Copying to build-linux/"
    cp ten_vad_ctypes.py build-linux/
    cp ten_vad_demo_ctypes.py build-linux/
    echo "    ✓ Deployed to Linux build directory"
    DEPLOYED=1
else
    echo "  ⚠ Linux build directory not found: build-linux"
fi

if [ "$DEPLOYED" -eq 1 ]; then
    echo "Deployment complete!"
else
    echo "No build directories found. Deployment failed!"
    exit 1
fi
echo ""
echo "Usage:"
echo "  cd build-linux  # or build-macos"
echo "  source ./venv/bin/activate  # For numpy"
echo "  python3 ten_vad_demo_ctypes.py ../../../examples/s0724-s0730.wav out-python-ctypes.txt"
echo ""
echo "Performance comparison with Python extension module:"
echo "  python3 ten_vad_demo.py ../../../examples/s0724-s0730.wav out-python.txt"
echo "  python3 ten_vad_demo_ctypes.py ../../../examples/s0724-s0730.wav out-python-ctypes.txt"
