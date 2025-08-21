TEN VAD Python ONNX example

This README describes linux build and demonstration of a Python extension
module (`lib/ten_vad_python.cypython*.so`) with Python bindings for the TEN VAD
C++/C library and ONNX runtime.

The build system is designed to work on these architectures.
| Architecture    | Notes                                        |
|-----------------|----------------------------------------------|
| ARM64 (aarch64) | tested Ubuntu 24.04.2 LTS with Python 3.12.3 |
| x64 (x86_64)    | should work                                  |

## 1. Prerequisites

The build uses cmake and runs in a virtual environment.
```bash
sudo apt update
sudo apt install cmake build-essential python3-venv
```

## 2. Install ONNX Runtime

Download for your architecture to your home directory:
- **ARM64**: [onnxruntime-linux-aarch64-1.22.0.tgz](https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-aarch64-1.22.0.tgz)
- **x86_64**: [onnxruntime-linux-x64-1.22.0.tgz](https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-x64-1.22.0.tgz)

This is automated with these environment variables.
 ```bash
ARCH=$(uname -m) && echo "Architecture: $ARCH"
ONNX_VER=1.22.0

cd
sudo apt install curl

curl -OL https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-$ARCH-$ONNX_VER.tgz

tar -xzf onnxruntime-linux-$ARCH-$ONNX_VER.tgz
rm onnxruntime-linux-$ARCH-$ONNX_VER.tgz
```

## 3. Build

The Python build script automatically:
- Creates virtual environment
- Installs pybind11 and numpy
- Detects architecture and finds ONNX Runtime
- Builds Python extension module in lib/ folder with CMake
- Creates necessary symlink to ONNX model file

```bash
cd ten-vad/examples_onnx
./build-and-deploy-python.sh
```

The compiled Python extension module is saved to `lib/` folder.
```bash
ls lib/
```
```console
ten_vad_python.cpython-312-aarch64-linux-gnu.so
```

Test import.
```bash
python3 -c 'import sys; sys.path.insert(0, "lib"); import ten_vad_python; print("Import success!")'
```

Remove ONNX Runtime folder (optional clean-up).
```bash
cd
rm -rf onnxruntime-linux-$ARCH-$ONNX_VER
```

## 4. Demo

This command line Python demo matches the functionality of compiled C demo.
e.g.: basic usage processes a WAV file and outputs results to text file.
```bash
python3 ten_vad_demo.py input.wav output.txt
```

The demo requires `numpy` package for handling audio from WAV file.  Create a
virtual environment for this dependency.
```bash
cd
python3 -m venv venv_demo
source ./venv_demo/bin/activate

python3 -m pip install --upgrade pip
python3 -m pip install numpy

cd ten-vad/examples_onnx
```

Run the demo with included sample.
```bash
python3 ten_vad_demo.py ../examples/s0724-s0730.wav out-python.txt
```

With custom threshold.
```bash
python3 ten_vad_demo.py ../examples/s0724-s0730.wav out-python-threshold.txt --threshold 0.6
```

### Output comparison of Python extension module and compiled C

The compiled C demo is created by `build-and-deploy-linux.sh`.

Running a diff shows some small magnitude differences with the probability
outputs from `s0724-s0730.wav`.  For three out of twenty consecutive frames:
```console
Python:  [35] 0.728302, 1    vs    C: [35] 0.728301, 1    (diff: 0.000001)
Python:  [42] 0.901945, 1    vs    C: [42] 0.901944, 1    (diff: 0.000001)
Python:  [54] 0.585849, 1    vs    C: [54] 0.585848, 1    (diff: 0.000001)
```
The difference is in the 6th decimal place (0.000001 scale) thus is not
expected to have any functional impact in real VAD use cases.

## Python API

```python
import sys
import os
import numpy as np  # For audio handling

# Add lib directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "lib"))

import ten_vad_python

# Create VAD instance
vad = ten_vad_python.VAD(hop_size=256, threshold=0.5)

# Process one audio frame (must be exactly hop_size samples)
audio_frame = np.array([...], dtype=np.int16)  # 256 samples
probability, is_voice = vad.process(audio_frame)

print(f"Voice probability: {probability:.6f}")
print(f"Is voice: {is_voice}")
```

## Files

- `build-and-deploy-python.sh` - Build script
- `CMakeLists-python.txt` - Python extension module CMake configuration
- `ten_vad_demo.py` - Python usage example
- `ten_vad_python.cc` - pybind11 wrapper

Python usage example requires these files on ARM64 with Python 3.12.
```console
examples_onnx
├── lib
│   └── ten_vad_python.cpython-312-aarch64-linux-gnu.so
├── onnx_model
│   └── ten-vad.onnx
└──ten_vad_demo.py
```

For x64 (x86_64) architecture build.
```console
├── lib
│   └── ten_vad_python.cpython-312-x86_64-linux-gnu.so
```
