# TEN VAD ONNX Examples

This directory contains examples for TEN VAD using ONNX Runtime:
- **C Demo**: Traditional C executable demo
- **Python Bindings**: Modern Python API with CMake build

## Quick Start

### 1. Prerequisites

The build uses cmake and runs a virtual environment.
```bash
sudo apt update
sudo apt install cmake build-essential python3-venv
```

### 2. Install ONNX Runtime

Download for your architecture to your home directory:
- **ARM64**: [onnxruntime-linux-aarch64-1.22.0.tgz](https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-aarch64-1.22.0.tgz)
- **x86_64**: [onnxruntime-linux-x64-1.22.0.tgz](https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-x64-1.22.0.tgz)

```bash
cd
sudo apt install curl

curl -OL https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-aarch64-1.22.0.tgz
tar -xzf onnxruntime-linux-aarch64-1.22.0.tgz
```

### 3. Build

**For Python bindings:**
```bash
cd ten-vad/examples_onnx
./build-and-deploy-python.sh
```

**For C demo:**
```bash
cd ten-vad/examples_onnx
./build-and-deploy-linux.sh --ort-path ~/onnxruntime-linux-aarch64-1.22.0
```

The Python build script automatically:
- Creates virtual environment
- Installs pybind11 and numpy
- Detects architecture and finds ONNX Runtime
- Builds with CMake
- Creates necessary symlinks

### 4. Use

**Command Line Demo (matches C demo functionality):**
```bash
# Basic usage - processes WAV file and outputs results
python3 ten_vad_demo.py input.wav output.txt

# With custom threshold
python3 ten_vad_demo.py input.wav output.txt --threshold 0.6

# Test with included sample
python3 ten_vad_demo.py ../examples/s0724-s0730.wav out-python.txt
```

**Python API:**
```python
import ten_vad_python
import numpy as np

# Create VAD instance
vad = ten_vad_python.VAD(hop_size=256, threshold=0.5)

# Process audio frame (must be exactly hop_size samples)
audio_frame = np.array([...], dtype=np.int16)  # 256 samples
probability, is_voice = vad.process(audio_frame)

print(f"Voice probability: {probability:.6f}")
print(f"Is voice: {is_voice}")
```

## Example

```python
# ten_vad_demo.py
import ten_vad
import numpy as np
import wave

# Load WAV file
with wave.open('audio.wav', 'rb') as f:
    frames = f.readframes(-1)
    audio = np.frombuffer(frames, dtype=np.int16)

# Process with VAD
vad = ten_vad.VAD()
prob, is_voice = vad.process(audio)
print(f"Voice detected: {is_voice} (confidence: {prob:.2f})")
```

## Files

**Python Bindings:**
- `CMakeLists-python.txt` - Python module CMake configuration
- `build-and-deploy-python.sh` - Python build script
- `ten_vad_demo.py` - Python usage example
- `ten_vad_python.cc` - Clean pybind11 wrapper

**C Demo:**
- `CMakeLists.txt` - C demo CMake configuration
- `build-and-deploy-linux.sh` - C demo build script

## Manual Build

If you prefer manual control:

```bash
# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install pybind11 numpy

# Build
mkdir build && cd build
cmake .. -DORT_ROOT=/path/to/onnxruntime
make -j$(nproc)
cp ten_vad*.so ..
```
