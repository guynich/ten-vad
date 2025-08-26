# TEN VAD ONNX Examples

This directory contains examples for building and using TEN VAD with ONNX
Runtime support. Follow the setup guide below to get started from scratch.

## 📋 Prerequisites & Setup

Follow these steps in order to set up your environment from nothing.

Test environments used for preparing this README.
* ONNX Runtime 1.22.0
* Python 3.12
* Linux: Ubuntu 24.04 LTS on ARM64 (native) and x86_64 (VM)
* macOS: Sequoia 15.6 on arm64 (native) and x86_64 (native)

### Step 1: Install System Dependencies

**Linux**
```bash
sudo apt update
sudo apt install cmake build-essential python3-venv curl
```

**macOS**
Install brew from [brew.sh](https://brew.sh).  In a new terminal session install
`cmake`.
```bash
brew install cmake
```

### Step 2: Download ONNX Runtime

Choose your platform and architecture, then download ONNX Runtime to your home
directory:

```bash
cd
# Set your ONNX Runtime version
ONNX_VER=1.22.0  # v1.17.1+

# Linux
ARCH=$(uname -m) && if [ "$ARCH" = "x86_64" ]; then ARCH="x64"; fi
curl -OL https://github.com/microsoft/onnxruntime/releases/download/v$ONNX_VER/onnxruntime-linux-$ARCH-$ONNX_VER.tgz
tar -xzf onnxruntime-linux-$ARCH-$ONNX_VER.tgz

# macOS
ARCH=$(uname -m) && if ! [ "$ARCH" = "x86_64" ]; then ARCH="arm64"; fi
curl -OL https://github.com/microsoft/onnxruntime/releases/download/v$ONNX_VER/onnxruntime-osx-$ARCH-$ONNX_VER.tgz
tar -xzf onnxruntime-osx-$ARCH-$ONNX_VER.tgz
```

Delete the `tgz` file if needed.

#### ONNX Runtime v1.22.0 package folders

| Platform | Architecture               | Package Name                       |
|----------|----------------------------|------------------------------------|
| Linux    | x86_64                     | `onnxruntime-linux-x64-1.22.0`     |
| Linux    | ARM64                      | `onnxruntime-linux-aarch64-1.22.0` |
| macOS    | Intel                      | `onnxruntime-osx-x86_64-1.22.0`    |
| macOS    | Apple Silicon              | `onnxruntime-osx-arm64-1.22.0`     |

## 🚀 Build Instructions

First navigate into the cloned TEN VAD repo.
```bash
cd
cd ten-vad/examples_onnx
```

Now that dependencies are installed, choose your platform and build type.

### Linux

#### C++ Demo
Build a standalone C++ executable that uses ONNX Runtime directly.

```bash
cd cpp
./build-and-deploy-linux.sh --ort-path ~/onnxruntime-linux-$ARCH-$ONNX_VER
```

**Output**: `cpp/build-linux/ten_vad_demo`

#### Python Extension Module
Build a Python extension module with pybind11 bindings.

```bash
cd python
./build-and-deploy-linux.sh --ort-path ~/onnxruntime-linux-$ARCH-$ONNX_VER
```

**Output** on ARM64: `python/build-linux/lib/ten_vad_python.cpython-312-aarch64-linux-gnu.so`

**Output** on X86_64: `python/build-linux/lib/ten_vad_python.cpython-312-x86_64-linux-gnu.so`

#### Python ctypes implementation

Runs significantly faster than the Python Extension Module with dependencies on
`ten-vad` repo source and `python/build*` scripts.

First run a build script in `python` folder.

Then deploy the ctypes implementation script - fails when build not available.
```bash
# Deploy ctypes implementation to build directories
cd python
./deploy_ctypes.sh
```
The script provides usage information.

### macOS

#### C++ Demo
Build a standalone C++ executable that uses ONNX Runtime directly.
```bash
cd cpp
./build-and-deploy-macos.sh --ort-path ~/onnxruntime-osx-$ARCH-$ONNX_VER
```

**Output**: `cpp/build-macos/ten_vad_demo`

#### Python Extension Module

Build a Python extension module optimized for macOS (supports both Intel and
Apple Silicon).

```bash
cd python
./build-and-deploy-macos.sh --ort-path ~/onnxruntime-osx-$ARCH-$ONNX_VER
```

**Output**: `python/build-macos/lib/ten_vad_python.*.so`

#### Python ctypes implementation

Follow the above section `Python ctypes implementation` - change the path names
for macOS build.

## Demo Usage

**Note**: All demos process the same input WAV file and output the
voice activity detection probability and `is_voice` flag.

### C++ Demo
From the build directory, run the demo executable:

```bash
# Linux
cd cpp/build-linux
./ten_vad_demo ../../../examples/s0724-s0730.wav out-cpp.txt

# macOS
cd cpp/build-macos
./ten_vad_demo ../../../examples/s0724-s0730.wav out-cpp.txt
```

### Python Extension Module
From the build directory, run the Python demo:

```bash
# Linux
cd python/build-linux
source ./venv/bin/activate  # For numpy
python3 ten_vad_demo.py ../../../examples/s0724-s0730.wav out-python.txt

# macOS
cd python/build-macos
source ./venv/bin/activate  # For numpy
python3 ten_vad_demo.py ../../../examples/s0724-s0730.wav out-python.txt

# With custom threshold on either Linux or macOS.
python3 ten_vad_demo.py ../../../examples/s0724-s0730.wav out-python-custom.txt --threshold 0.6
```

### Python ctypes Implementation
The cytypes implementation runs significantly faster than the Python Extension
Module.  Examples are shared in Performance comparison below.

This implementation has dependencies on `ten-vad` repo and Python extension
module build folder.

From the build directory, run the Python ctypes demo:
```bash
# Use from build directory with virtual environment for numpy.
cd python/build-linux  # or build-macos
source ./venv/bin/activate  # For numpy
python3 ten_vad_demo_ctypes.py ../../../examples/s0724-s0730.wav out-python-ctypes.txt

# With custom threshold
python3 ten_vad_demo_ctypes.py ../../../examples/s0724-s0730.wav out-python-ctypes-custome.txt --threshold 0.6
```

## 📊 Performance Comparison

### Output Comparison of Python methods and Compiled C

The C++ demo and Python extension module and Python ctypes process the same WAV
file with nearly identical results:

**Accuracy Analysis:**
1. **Voice Activity Detection**: `is_voice` flags are identical for all 476 frames
2. **Probability Values** compared wih C++ demo:

   a. Python ctypes achieves **perfect numerical precision** matching probability values exactly (476 frames, 100% identical)

   b. Python extension module: 440 frames (92.4%) have identical probabilities; 36 frames (7.6%) differ only in the 6th decimal place

3. **Precision**: For Python extension module in separate testing, the differences are in the 7th-8th decimal place (mean: 6 × 10⁻⁸, max: 5.9 × 10⁻⁷)

Selected examples for Python extension module:
```console
Python:  [35] 0.728302, 1    vs    C: [35] 0.728301, 1    (diff: 0.000001)
Python:  [42] 0.901945, 1    vs    C: [42] 0.901944, 1    (diff: 0.000001)
Python:  [54] 0.585849, 1    vs    C: [54] 0.585848, 1    (diff: 0.000001)
```

**Conclusion**: These tiny differences have no functional impact.  Both the Python
ctypes and the Python Extension Module provide faithful, high-quality
interfaces to the TEN VAD C/C++ library.

### Real-time Factor (RTF) Comparison

Testing Ubuntu 24.04 running on ARM CPU (Orange Pi 5 8-core ARM64 RockChip
RK3588S).

| Method                  | Time (ms) | Audio (ms) |   RTF    |
|-------------------------|:---------:|:----------:|:--------:|
| C++ Demo                |   74.0    |    7631    | 0.009697 |
| Python ctypes           |   98.9    |    7631    | 0.012960 |
| Python Extension Module |   192.5   |    7631    | 0.025222 |

These are single shot examples.  There is run-run variation.

The C++ demo is 2.6x faster than the Python extension module. The ctypes demo is
nearly 2x faster than the Python extension module.   For latency-critical
applications, choose the compiled C++ version or Python ctypes.

## 🐍 Python Usage

Example for macOS.
```python
import sys
import numpy as np

# Add the built module to path
sys.path.insert(0, "python/build-macos/lib")  # macOS
# sys.path.insert(0, "python/build-linux-python/lib")  # Linux

import ten_vad_python

# Create VAD instance
vad = ten_vad_python.VAD(hop_size=256, threshold=0.5)

# Process audio frame (must be exactly hop_size samples)
audio_frame = np.array([...], dtype=np.int16)  # 256 samples
probability, is_voice = vad.process(audio_frame)

print(f"Voice probability: {probability:.6f}")
print(f"Is voice: {is_voice}")
```

### ctypes Implementation

Example for using the ctypes wrapper:

```python
import sys
import numpy as np

# Add the ctypes module to path
sys.path.insert(0, "python/build-macos")  # macOS
# sys.path.insert(0, "python/build-linux")  # Linux

import ten_vad_ctypes

# Create VAD instance (same API as pybind11)
vad = ten_vad_ctypes.VAD(hop_size=256, threshold=0.5)

# Process audio frame (must be exactly hop_size samples)
audio_frame = np.array([...], dtype=np.int16)  # 256 samples
probability, is_voice = vad.process(audio_frame)

print(f"Voice probability: {probability:.6f}")
print(f"Is voice: {is_voice}")
```

**Performance Benefits:**
- **Nearly ~2x faster** than Python extension module (Linux ARM64 testing)
- **Identical precision** to CPP demo
- **Drop-in replacement** - same API as pybind11 version

**Deployment Requirements:**
- Copy `ten_vad_ctypes.py` to your project
- Ensure TEN VAD framework is accessible (uses existing repo structure)
- Run Linux build for Python extension module then use `./deploy_ctypes.sh` for automated deployment

## 📁 Project Structure

```
examples_onnx/
├── README.md                          # This file
├── CMakeLists.txt                     # Root build configuration
├── cpp/                               # C++ demo (Linux + macOS)
│   ├── CMakeLists.txt
│   ├── build-and-deploy-linux.sh
│   └── build-and-deploy-macos.sh
├── python/                            # Python implementations (Linux + macOS)
│   ├── CMakeLists.txt
│   ├── build-and-deploy-linux.sh
│   ├── build-and-deploy-macos.sh
│   ├── ten_vad_demo.py                # Python demo script (pybind11)
│   ├── ten_vad_ctypes.py              # ctypes wrapper (performance optimized)
│   ├── ten_vad_demo_ctypes.py         # ctypes demo script
│   └── deploy_ctypes.sh               # Deploy ctypes to build directories
└── ten_vad_python.cc                  # pybind11 wrapper

```

## Build notes

### Environment Detection
- **Python Version**: Automatically uses your active Python (supports pyenv)
- **Architecture**: Auto-detects x86_64/ARM64 for ONNX Runtime selection
- **Platform**: Automatically configures for Linux/macOS differences

### Troubleshooting

**Python Import Error**: Ensure the module is in your Python path and built for
the correct Python version.  Numpy is needed for WAV audio handling.

**ONNX Runtime Not Found**: Verify the `--ort-path` points to a valid ONNX
Runtime installation with `lib/` and `include/` directories.

**Architecture Mismatch**: Ensure your ONNX Runtime package matches your system
architecture.

**Permission Denied**: Make sure build scripts are executable: `chmod +x *.sh`

## 📖 Additional Resources

- [Main TEN VAD Repository](../../README.md)
- [ONNX Runtime Releases](https://github.com/microsoft/onnxruntime/releases)
- [TEN VAD Python Examples](python/ten_vad_demo.py)

---
