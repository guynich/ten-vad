# TEN VAD Python Bindings - Troubleshooting

## Common Build Issues and Solutions

These identified on **ARM64** running Ubuntu OS 24.04.2.

### 1. ModuleNotFoundError: No module named 'setuptools' or 'distutils'

**Symptoms:**
```
ModuleNotFoundError: No module named 'setuptools'
ModuleNotFoundError: No module named 'distutils'
```

**Solution:**
Create a fresh virtual environment and install all dependencies:

```bash
# Remove old virtual environment if it exists
rm -rf venv_tenvad

# Create fresh virtual environment
python3 -m venv venv_tenvad

# Activate virtual environment
source venv_tenvad/bin/activate

# Install requirements (includes setuptools and wheel)
pip install -r requirements.txt

# Build the extension
python setup.py build_ext --inplace
```

### 2. Externally-managed-environment Error

**Symptoms:**
```
error: externally-managed-environment
× This environment is externally managed
```

**Solution:**
This happens when pip tries to install packages system-wide. Always use a virtual environment:

```bash
# Make sure you're in a virtual environment
python3 -m venv venv_tenvad
source venv_tenvad/bin/activate

# Then proceed with installation
pip install -r requirements.txt
```

### 3. ONNX Runtime Not Found

**Symptoms:**
```
ERROR: ONNX Runtime not found at /home/user/onnxruntime-linux-*
```

**Solution:**
Download the correct ONNX Runtime for your architecture:

**For ARM64/aarch64 systems:**
```bash
cd ~
wget https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-aarch64-1.22.0.tgz
tar -xzf onnxruntime-linux-aarch64-1.22.0.tgz
```

**For x86_64 systems:**
```bash
cd ~
wget https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-x64-1.22.0.tgz
tar -xzf onnxruntime-linux-x64-1.22.0.tgz
```

### 4. Import Error at Runtime

**Symptoms:**
```
ImportError: libonnxruntime.so.1: cannot open shared object file
```

**Solution:**
The ONNX Runtime library path is not set correctly. Try:

```bash
# Check if the symlink exists
ls -la onnx_model/

# If not, create it
ln -sf ../src/onnx_model .

# Or specify the ONNX Runtime path explicitly
export LD_LIBRARY_PATH=/home/$(whoami)/onnxruntime-linux-aarch64-1.22.0/lib:$LD_LIBRARY_PATH
```

### 5. Architecture Mismatch

**Symptoms:**
```
/usr/bin/ld: file in wrong format
```

**Solution:**
You're using the wrong ONNX Runtime architecture. Check your system:

```bash
uname -m
```

- If `aarch64`: Use `onnxruntime-linux-aarch64-1.22.0`
- If `x86_64`: Use `onnxruntime-linux-x64-1.22.0`

### 6. Missing Build Tools

**Symptoms:**
```
error: Microsoft Visual C++ 14.0 is required
error: command 'gcc' failed
```

**Solution:**
Install build tools:

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install build-essential python3-dev

# Or if you prefer
sudo apt install gcc g++ make
```

## Manual Build Steps

If the automated build script fails, try these manual steps:

### Method 1: Simple Setup (Recommended)

```bash
# 1. Create and activate virtual environment
python3 -m venv venv_tenvad
source venv_tenvad/bin/activate

# 2. Install dependencies
pip install numpy pybind11 setuptools wheel

# 3. Build extension
python setup.py build_ext --inplace

# 4. Create ONNX model symlink
ln -sf ../src/onnx_model .

# 5. Test
python vad_demo.py ../examples/s0724-s0730.wav output.txt
```

### Method 2: CMake Build

```bash
# 1. Install dependencies
sudo apt install cmake build-essential python3-dev

# 2. Create build directory
mkdir build
cd build

# 3. Configure and build
cp ../CMakeLists_python.txt ./CMakeLists.txt
cmake . -DORT_ROOT=$HOME/onnxruntime-linux-aarch64-1.22.0
make -j$(nproc)

# 4. Copy module back
cp ten_vad_python*.so ../
cd ..
```

## Performance Tips

1. **Use 16kHz audio** for optimal performance
2. **Process in batches** rather than frame-by-frame when possible
3. **Check RTF (Real-Time Factor)** - should be < 1.0 for real-time applications
4. **Use appropriate hop_size** - 256 samples (16ms) is recommended for 16kHz audio

## Getting Help

If you continue to have issues:

1. Check that all requirements in `requirements.txt` are installed
2. Verify your architecture matches the ONNX Runtime download
3. Ensure you're using a virtual environment
4. Try building manually: `python setup.py build_ext --inplace`
5. Check the file permissions on the build scripts: `chmod +x *.sh`

## Verify Installation

After successful build, verify everything works:

```bash
# Basic import test
python -c "import ten_vad_python; print('SUCCESS:', ten_vad_python.get_version())"

# Full demo test
python vad_demo.py ../examples/s0724-s0730.wav test_output.txt

# Frame-by-frame test
python vad_demo.py ../examples/s0724-s0730.wav test_output.txt --frame-demo
```

Expected output should show:
- RTF < 0.01 (very fast processing)
- Voice detected in ~73% of frames for the sample audio
- No import or runtime errors
