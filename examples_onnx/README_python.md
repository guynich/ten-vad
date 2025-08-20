# TEN VAD Python Bindings

This directory contains Python bindings for the TEN VAD (Voice Activity
Detection) library using pybind11.

Tested on ARM64 running Ubuntu 24.04.2 LTS with Python 3.12.3.

## Overview

The Python bindings provide a clean, easy-to-use interface to the TEN VAD C/C++
library, allowing you to perform voice activity detection directly from Python
with the power of ONNX Runtime.

## Files

- `ten_vad_python.cpp` - pybind11 wrapper implementation
- `setup.py` - Python package build configuration (simple and robust)
- `vad_demo.py` - Complete example script for audio processing
- `build_python.sh` - Build script with automatic architecture detection
- `requirements.txt` - Python dependencies
- `CMakeLists_python.txt` - CMake build configuration (alternative to setuptools)

## Quick Start

Assumes `ten-vad` repo is in user's home folder.

### 1. Prerequisites

Get the basic build tools and ONNX Runtime.

```bash
sudo apt update
sudo apt install python3-venv build-essential
```

**ONNX Runtime:** Download the correct version for your architecture to your home folder:
- **ARM64**: [onnxruntime-linux-aarch64-1.22.0.tgz](https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-aarch64-1.22.0.tgz)
- **x86_64**: [onnxruntime-linux-x64-1.22.0.tgz](https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-x64-1.22.0.tgz)

Example for **ARM64**.
```bash
sudo apt update
sudo apt install curl

cd
curl -OL https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-aarch64-1.22.0.tgz

tar -zxvf onnxruntime-linux-aarch64-1.22.0.tgz
rm onnxruntime-linux-aarch64-1.22.0.tgz
```

### 2. Build the Extension

The build script handles everything automatically:

```bash
cd
cd ten-vad/examples_onnx
./build_python.sh
```

**That's it!** The script automatically:
- Creates virtual environment (if not already in one)
- Detects your architecture and finds correct ONNX Runtime
- Installs all Python dependencies
- Creates ONNX model symlinks
- Builds and tests the extension

**Optional parameters:**
```bash
# Specify custom ONNX Runtime path
./build_python.sh --ort-path /path/to/your/onnxruntime

# Use CMake instead of setuptools
./build_python.sh --cmake

# Skip dependency installation (if already installed)
./build_python.sh --skip-deps
```

### 3. Run the Demo

The demo requires `numpy` package.

```bash
cd
python3 -m venv venv_tenvad
source ./venv_tenvad/bin/activate

cd ten-vad/examples_onnx
python3 -m pip install --upgrade pip
python3 -m pip install numpy
```

```bash
# Basic usage.
python3 vad_demo.py ../examples/s0724-s0730.wav output.txt

# With custom threshold.
python3 vad_demo.py audio.wav results.txt --threshold 0.6

# Frame-by-frame processing demo.
python3 vad_demo.py audio.wav results.txt --frame-demo
```

## API Usage

### Basic Example

```python
import numpy as np
import ten_vad_python

# Create VAD instance
vad = ten_vad_python.TenVAD(hop_size=256, threshold=0.5)

# Process audio data (numpy array of int16)
audio_data = np.array([...], dtype=np.int16)  # Your audio samples
probabilities, flags = vad.process_audio(audio_data)

# Results:
# - probabilities: float array with VAD confidence [0.0-1.0]
# - flags: int array with binary decisions (0=no voice, 1=voice)
```

### Frame-by-Frame Processing

```python
import ten_vad_python

vad = ten_vad_python.TenVAD(hop_size=256, threshold=0.5)

# Process single frame (useful for real-time applications)
frame = np.array([...], dtype=np.int16)  # Must be exactly hop_size samples
probability, flag = vad.process_frame(frame)

print(f"Voice probability: {probability:.3f}, Voice detected: {flag}")
```

### Complete Audio File Processing

```python
import numpy as np
import ten_vad_python

def process_wav_file(filename):
    # Read your WAV file (16-bit PCM, preferably 16kHz)
    # ... audio loading code ...

    # Create VAD instance
    vad = ten_vad_python.TenVAD(hop_size=256, threshold=0.5)

    # Process entire audio
    probabilities, flags = vad.process_audio(audio_data)

    # Analyze results
    voice_frames = np.sum(flags)
    total_frames = len(flags)
    voice_percentage = (voice_frames / total_frames) * 100

    print(f"Voice detected in {voice_frames}/{total_frames} frames ({voice_percentage:.1f}%)")

    return probabilities, flags
```

## API Reference

### TenVAD Class

#### Constructor
```python
TenVAD(hop_size=256, threshold=0.5)
```
- `hop_size`: Number of samples per frame (default: 256 = 16ms at 16kHz)
- `threshold`: VAD threshold [0.0-1.0] (default: 0.5)

#### Methods

**`process_frame(audio_data)`**
- Process a single audio frame
- `audio_data`: numpy array of int16, must be exactly `hop_size` samples
- Returns: `(probability, flag)` tuple

**`process_audio(audio_data)`**
- Process entire audio buffer
- `audio_data`: numpy array of int16, length must be divisible by `hop_size`
- Returns: `(probabilities, flags)` tuple of numpy arrays

**`get_hop_size()`**
- Returns the hop size

**`get_threshold()`**
- Returns the VAD threshold

**`get_version()`**
- Returns the TEN VAD library version

#### Module Functions

**`ten_vad_python.get_version()`**
- Get library version string

## Audio Requirements

- **Format**: 16-bit PCM
- **Sample Rate**: 16kHz (recommended, though other rates may work)
- **Channels**: Mono (stereo will be converted to mono by averaging)
- **Frame Size**: Audio length must be divisible by `hop_size`

## Architecture Support

The build system automatically detects your architecture:

- **x86_64**: Uses `onnxruntime-linux-x64-1.22.0`
- **aarch64/arm64**: Uses `onnxruntime-linux-aarch64-1.22.0`

## Troubleshooting

### Build Issues

1. **Missing pybind11**: `pip3 install pybind11`
2. **Missing numpy**: `pip3 install numpy`
3. **Wrong ONNX Runtime**: Download the correct architecture version
4. **Permission errors**: Make sure `build_python.sh` is executable

### Runtime Issues

1. **Import error**: Make sure the `.so` file is in the same directory
2. **ONNX Runtime not found**: Check that the library path is correct
3. **Audio format errors**: Ensure 16-bit PCM format

### Performance Tips

1. Use 16kHz audio for optimal performance
2. Process in batches for better efficiency
3. Consider the RTF (Real-Time Factor) for your use case

## Examples

See `vad_demo.py` for a complete example with:
- WAV file reading
- Error handling
- Performance measurement
- Results analysis
- Both batch and frame-by-frame processing

## License

Copyright © 2025 Agora
Licensed under the Apache License, Version 2.0

# Next steps

- [x] debug cmake build
