#!/usr/bin/env python3
#
#  Copyright © 2025 Agora
#  This file is part of TEN Framework, an open source project.
#  Licensed under the Apache License, Version 2.0, with certain conditions.
#  Refer to the "LICENSE" file in the root directory for more information.
#
"""
ctypes wrapper for TEN VAD
Drop-in replacement for the pybind11 extension module.
"""

import os
import platform
from ctypes import CDLL, POINTER, c_float, c_int, c_int32, c_size_t, c_void_p

import numpy as np


class VAD:
    """
    ctypes-based VAD wrapper that matches the pybind11 interface.
    Optimized for minimal per-call overhead.
    """

    def __init__(self, hop_size: int = 256, threshold: float = 0.5):
        self.hop_size = hop_size
        self.threshold = threshold

        # Load the shared library
        self._load_library()

        # Pre-allocate output variables to avoid repeated allocation
        self._out_probability = c_float()
        self._out_flags = c_int32()
        self._vad_handle = c_void_p(0)

        # Set up function signatures once
        self._setup_function_signatures()

        # Create VAD instance
        self._create_vad()

    def _load_library(self):
        """Load the appropriate shared library for the current platform."""
        script_dir = os.path.dirname(os.path.abspath(__file__))

        # Determine library name and expected locations based on platform
        if platform.system() == "Darwin":  # macOS
            lib_name = "libten_vad.dylib"
            # Look for library in standard locations relative to script
            lib_paths = [
                # Current directory (python/build-macos/)
                f"{lib_name}",
                # Lib subdirectory (python/build-macos/lib/)
                f"lib/{lib_name}",
                # Parent directories for when run from examples_onnx/
                f"build-macos/{lib_name}",
                f"cpp/build-macos/{lib_name}",
                f"python/build-macos/{lib_name}",
                f"python/build-macos/lib/{lib_name}",
                # Absolute paths relative to script location
                f"../{lib_name}",
                f"../../cpp/build-macos/{lib_name}",
                # Pre-built framework paths - adjust based on script location
                "../../../lib/macOS/ten_vad.framework/Versions/A/ten_vad",  # From examples_onnx/
                "../../../../lib/macOS/ten_vad.framework/Versions/A/ten_vad",  # From python/build-macos/
                "../../lib/macOS/ten_vad.framework/Versions/A/ten_vad",  # From examples_onnx/python/
            ]
        elif platform.system() == "Linux":
            lib_name = "libten_vad.so"
            lib_paths = [
                # Current directory
                lib_name,
                # Standard lib subdirectory
                f"lib/{lib_name}",
                # Parent build directory (if run from python/build-linux/)
                f"../{lib_name}",
                f"../../cpp/build-linux/{lib_name}",
                # System library path (only x86_64 available)
                f"../../../lib/Linux/x64/{lib_name}"
            ]
        else:
            raise NotImplementedError(f"Unsupported platform: {platform.system()}")

        # Try to load the library from the most likely locations first
        for lib_path in lib_paths:
            full_path = os.path.join(script_dir, lib_path)
            if os.path.exists(full_path):
                try:
                    self.vad_library = CDLL(full_path)
                    print(f"Loaded TEN VAD library from: {full_path}")
                    return
                except OSError as e:
                    print(f"Failed to load {full_path}: {e}")
                    continue

        # If we get here, show attempted paths for debugging
        attempted_paths = [os.path.join(script_dir, path) for path in lib_paths]
        raise RuntimeError(
            f"Could not load TEN VAD library. Tried paths:\n"
            + "\n".join(
                f"  {path} (exists: {os.path.exists(path)})" for path in attempted_paths
            )
        )

    def _setup_function_signatures(self):
        """Set up ctypes function signatures for better performance."""
        # ten_vad_create
        self.vad_library.ten_vad_create.argtypes = [
            POINTER(c_void_p),
            c_size_t,
            c_float,
        ]
        self.vad_library.ten_vad_create.restype = c_int

        # ten_vad_process
        self.vad_library.ten_vad_process.argtypes = [
            c_void_p,
            c_void_p,
            c_size_t,
            POINTER(c_float),
            POINTER(c_int32),
        ]
        self.vad_library.ten_vad_process.restype = c_int

        # ten_vad_destroy
        self.vad_library.ten_vad_destroy.argtypes = [POINTER(c_void_p)]
        self.vad_library.ten_vad_destroy.restype = c_int

        # ten_vad_get_version
        self.vad_library.ten_vad_get_version.restype = c_void_p

    def _create_vad(self):
        """Create the VAD handle."""
        result = self.vad_library.ten_vad_create(
            POINTER(c_void_p)(self._vad_handle),
            c_size_t(self.hop_size),
            c_float(self.threshold),
        )
        if result != 0:
            raise RuntimeError("Failed to create VAD instance")

    def process(self, audio_frame: np.ndarray) -> tuple[float, bool]:
        """
        Process a single audio frame.

        Args:
            audio_frame: numpy array of int16 audio samples, length must equal hop_size

        Returns:
            tuple: (probability, is_voice) where probability is float and is_voice is bool
        """
        # Validate input (can be removed in production for extra speed)
        if audio_frame.size != self.hop_size:
            raise ValueError(
                f"Audio frame size ({audio_frame.size}) must match hop_size ({self.hop_size})"
            )

        if audio_frame.dtype != np.int16:
            raise ValueError("Audio frame must be int16 dtype")

        # Get pointer to numpy data - this is very fast
        audio_ptr = audio_frame.ctypes.data_as(c_void_p)

        # Call the C function
        result = self.vad_library.ten_vad_process(
            self._vad_handle,
            audio_ptr,
            c_size_t(self.hop_size),
            POINTER(c_float)(self._out_probability),
            POINTER(c_int32)(self._out_flags),
        )

        if result != 0:
            raise RuntimeError("VAD processing failed")

        return self._out_probability.value, bool(self._out_flags.value)

    def version(self) -> str:
        """Get the VAD version string."""
        ptr = self.vad_library.ten_vad_get_version()
        return str(ptr)

    def __del__(self):
        """Clean up VAD resources."""
        if hasattr(self, "_vad_handle") and self._vad_handle:
            try:
                self.vad_library.ten_vad_destroy(POINTER(c_void_p)(self._vad_handle))
            except:
                pass  # Ignore errors during cleanup
