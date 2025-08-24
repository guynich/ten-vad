#!/bin/bash
#
#  Copyright © 2025 Agora
#  This file is part of TEN Framework, an open source project.
#  Licensed under the Apache License, Version 2.0, with certain conditions.
#  Refer to the "LICENSE" file in the root directory for more information.
#
# Wrapper script for C++ demo build.
set -euo pipefail

echo "Building C++ demo..."
echo "Note: Build artifacts will be in cpp/build-linux/"
cd cpp
exec ./build-and-deploy-linux.sh "$@"