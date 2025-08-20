#!/usr/bin/env python3
"""
Copyright © 2025 Agora
This file is part of TEN Framework, an open source project.
Licensed under the Apache License, Version 2.0, with certain conditions.
Refer to the "LICENSE" file in the root directory for more information.

Simple Python package build configuration without pybind11 setup helpers
"""

import os
import sys
import platform
from setuptools import setup, Extension
import pybind11

# Get architecture for correct ONNX Runtime path
arch = platform.machine().lower()
if arch == 'x86_64':
    ort_arch = 'x64'
    ort_dir_name = 'onnxruntime-linux-x64-1.22.0'
elif arch in ['aarch64', 'arm64']:
    ort_arch = 'aarch64'
    ort_dir_name = 'onnxruntime-linux-aarch64-1.22.0'
else:
    raise RuntimeError(f"Unsupported architecture: {arch}")

# Path setup
home_dir = os.path.expanduser("~")
project_root = os.path.dirname(os.path.abspath(__file__))
ten_vad_root = os.path.dirname(project_root)
src_dir = os.path.join(ten_vad_root, "src")
include_dir = os.path.join(ten_vad_root, "include")
ort_root = os.path.join(home_dir, ort_dir_name)

print(f"Detected architecture: {arch}")
print(f"TEN VAD root: {ten_vad_root}")
print(f"ONNX Runtime path: {ort_root}")

# Check if ONNX Runtime exists
if not os.path.exists(ort_root):
    print(f"ERROR: ONNX Runtime not found at {ort_root}")
    print(f"Please download and extract ONNX Runtime for {arch}")
    if arch == 'x86_64':
        print("Download: https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-x64-1.22.0.tgz")
    else:
        print("Download: https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-aarch64-1.22.0.tgz")
    sys.exit(1)

# Source files from the TEN VAD library
source_files = [
    "ten_vad_python.cpp",  # Our pybind11 wrapper
    os.path.join(src_dir, "ten_vad.cc"),
    os.path.join(src_dir, "aed.cc"),
    os.path.join(src_dir, "biquad.cc"),
    os.path.join(src_dir, "fftw.c"),
    os.path.join(src_dir, "fscvrt.cc"),
    os.path.join(src_dir, "pitch_est.cc"),
    os.path.join(src_dir, "stft.cc"),
]

# Include directories
include_dirs = [
    pybind11.get_include(),
    include_dir,
    src_dir,
    os.path.join(ort_root, "include"),
]

# Library directories and libraries
library_dirs = [
    os.path.join(ort_root, "lib"),
]

libraries = [
    "onnxruntime",
]

# Compiler and linker flags
extra_compile_args = [
    "-std=c++14",
    "-O3",
    "-Wno-write-strings",
    "-Wno-unused-result",
    "-fPIC",
]

# Runtime library path
extra_link_args = [
    f"-Wl,-rpath,{os.path.join(ort_root, 'lib')}",
    "-Wl,--disable-new-dtags",  # Use RPATH instead of RUNPATH
]

# Define the extension using standard setuptools Extension
ext_modules = [
    Extension(
        "ten_vad_python",
        sources=source_files,
        include_dirs=include_dirs,
        library_dirs=library_dirs,
        libraries=libraries,
        extra_compile_args=extra_compile_args,
        extra_link_args=extra_link_args,
        language="c++",
    ),
]

if __name__ == "__main__":
    setup(
        name="ten_vad_python",
        version="1.0.0",
        author="TEN Framework",
        description="Python bindings for TEN VAD (Voice Activity Detection)",
        long_description="Python bindings for TEN VAD library using ONNX Runtime",
        ext_modules=ext_modules,
        python_requires=">=3.7",
        install_requires=[
            "numpy",
            "pybind11>=2.6.0",
        ],
        zip_safe=False,
    )
