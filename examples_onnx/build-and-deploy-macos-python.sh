#!/bin/bash
#
#  Copyright © 2025 Agora
#  This file is part of TEN Framework, an open source project.
#  Licensed under the Apache License, Version 2.0, with certain conditions.
#  Refer to the "LICENSE" file in the root directory for more information.
#
# Wrapper script for Python extension module build on macOS.
set -e

echo "Building Python bindings on macOS..."
echo "Note: Build artifacts will be in python/build-macos-python/"
cd python
exec ./build-and-deploy-macos-python.sh "$@"