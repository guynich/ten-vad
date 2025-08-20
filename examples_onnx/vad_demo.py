#!/usr/bin/env python3
"""
Copyright © 2025 Agora
This file is part of TEN Framework, an open source project.
Licensed under the Apache License, Version 2.0, with certain conditions.
Refer to the "LICENSE" file in the root directory for more information.

TEN VAD Python Demo Script

This script demonstrates how to use the TEN VAD library from Python to perform
voice activity detection on audio files. It supports WAV files and provides
real-time processing capabilities.

Usage:
    python vad_demo.py input.wav output.txt
    python vad_demo.py input.wav output.txt --threshold 0.6 --hop-size 256
"""

import argparse
import sys
import time
import struct
import os
from pathlib import Path
import numpy as np

try:
    import ten_vad_python
except ImportError:
    print("ERROR: ten_vad_python module not found!")
    print("Please build the module first:")
    print("  python setup.py build_ext --inplace")
    sys.exit(1)


class WAVReader:
    """Simple WAV file reader for 16-bit PCM audio."""

    def __init__(self, filename):
        self.filename = filename
        self.file = None
        self.sample_rate = None
        self.num_channels = None
        self.bits_per_sample = None
        self.data_offset = None
        self.data_size = None

    def __enter__(self):
        self.file = open(self.filename, 'rb')
        self._read_header()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.file:
            self.file.close()

    def _read_header(self):
        """Read WAV file header and extract metadata."""
        # Read RIFF header
        riff_header = self.file.read(12)
        if len(riff_header) != 12:
            raise ValueError("Invalid WAV file: cannot read RIFF header")

        if riff_header[:4] != b'RIFF' or riff_header[8:12] != b'WAVE':
            raise ValueError("Invalid WAV file: not a RIFF/WAVE file")

        # Read chunks until we find fmt and data
        fmt_found = False
        data_found = False

        while not (fmt_found and data_found):
            chunk_header = self.file.read(8)
            if len(chunk_header) != 8:
                break

            chunk_id = chunk_header[:4]
            chunk_size = struct.unpack('<I', chunk_header[4:8])[0]

            if chunk_id == b'fmt ':
                # Read format chunk
                fmt_data = self.file.read(chunk_size)
                if len(fmt_data) >= 16:
                    fmt_info = struct.unpack('<HHIIHH', fmt_data[:16])
                    audio_format = fmt_info[0]
                    self.num_channels = fmt_info[1]
                    self.sample_rate = fmt_info[2]
                    self.bits_per_sample = fmt_info[5]

                    if audio_format != 1:  # PCM
                        raise ValueError("Only PCM format is supported")
                    if self.bits_per_sample != 16:
                        raise ValueError("Only 16-bit audio is supported")

                fmt_found = True

            elif chunk_id == b'data':
                # Found data chunk
                self.data_size = chunk_size
                self.data_offset = self.file.tell()
                data_found = True
                break

            else:
                # Skip unknown chunk
                self.file.seek(chunk_size + (chunk_size % 2), 1)

        if not fmt_found:
            raise ValueError("WAV file missing fmt chunk")
        if not data_found:
            raise ValueError("WAV file missing data chunk")

    def read_audio_data(self):
        """Read all audio data as int16 numpy array."""
        self.file.seek(self.data_offset)
        raw_data = self.file.read(self.data_size)

        # Convert to numpy array of int16
        audio_data = np.frombuffer(raw_data, dtype=np.int16)

        # Convert to mono if stereo (simple average)
        if self.num_channels == 2:
            audio_data = audio_data.reshape(-1, 2)
            audio_data = np.mean(audio_data, axis=1).astype(np.int16)
        elif self.num_channels > 2:
            audio_data = audio_data.reshape(-1, self.num_channels)
            audio_data = np.mean(audio_data, axis=1).astype(np.int16)

        return audio_data

    def get_duration_ms(self):
        """Get audio duration in milliseconds."""
        if self.sample_rate and self.data_size:
            samples_per_channel = self.data_size // (2 * self.num_channels)  # 2 bytes per sample
            return (samples_per_channel / self.sample_rate) * 1000
        return 0


def process_audio_file(input_file, output_file, hop_size=256, threshold=0.5, verbose=True):
    """
    Process an audio file with TEN VAD and save results.

    Args:
        input_file: Path to input WAV file
        output_file: Path to output text file
        hop_size: Number of samples per frame (default: 256)
        threshold: VAD threshold (default: 0.5)
        verbose: Print progress information
    """

    print(f"TEN VAD Python Demo")
    print(f"Library version: {ten_vad_python.get_version()}")
    print(f"Processing: {input_file}")
    print(f"Hop size: {hop_size}, Threshold: {threshold}")
    print("-" * 50)

    # Read audio file
    try:
        with WAVReader(input_file) as wav:
            print(f"Sample rate: {wav.sample_rate} Hz")
            print(f"Channels: {wav.num_channels}")
            print(f"Bits per sample: {wav.bits_per_sample}")
            print(f"Duration: {wav.get_duration_ms():.2f} ms")

            if wav.sample_rate != 16000:
                print("WARNING: TEN VAD is optimized for 16kHz audio")

            audio_data = wav.read_audio_data()

    except Exception as e:
        print(f"ERROR reading audio file: {e}")
        return False

    print(f"Audio samples: {len(audio_data)}")

    # Ensure audio length is divisible by hop_size
    total_frames = len(audio_data) // hop_size
    if len(audio_data) % hop_size != 0:
        print(f"WARNING: Truncating audio to {total_frames * hop_size} samples")
        audio_data = audio_data[:total_frames * hop_size]

    print(f"Processing {total_frames} frames...")

    # Initialize VAD
    try:
        vad = ten_vad_python.TenVAD(hop_size=hop_size, threshold=threshold)
        print(f"VAD initialized: hop_size={vad.get_hop_size()}, threshold={vad.get_threshold()}")
    except Exception as e:
        print(f"ERROR initializing VAD: {e}")
        return False

    # Process audio
    start_time = time.time()

    try:
        probabilities, flags = vad.process_audio(audio_data)
    except Exception as e:
        print(f"ERROR processing audio: {e}")
        return False

    processing_time = time.time() - start_time

    # Calculate statistics
    audio_duration_ms = len(audio_data) / 16.0  # Assuming 16kHz
    rtf = (processing_time * 1000) / audio_duration_ms
    voice_frames = np.sum(flags)
    voice_percentage = (voice_frames / total_frames) * 100

    print(f"\nProcessing completed!")
    print(f"Processing time: {processing_time*1000:.2f} ms")
    print(f"Audio duration: {audio_duration_ms:.2f} ms")
    print(f"Real-time factor (RTF): {rtf:.6f}")
    print(f"Voice frames: {voice_frames}/{total_frames} ({voice_percentage:.1f}%)")

    # Save results
    try:
        with open(output_file, 'w') as f:
            f.write(f"# TEN VAD Results\n")
            f.write(f"# Input: {input_file}\n")
            f.write(f"# Hop size: {hop_size}, Threshold: {threshold}\n")
            f.write(f"# Total frames: {total_frames}, Voice frames: {voice_frames}\n")
            f.write(f"# Frame  Probability  Flag\n")

            for i in range(total_frames):
                f.write(f"[{i}] {probabilities[i]:.6f}, {flags[i]}\n")

        print(f"Results saved to: {output_file}")

    except Exception as e:
        print(f"ERROR saving results: {e}")
        return False

    # Print some sample results
    if verbose and total_frames > 0:
        print(f"\nSample results (first 10 frames):")
        for i in range(min(10, total_frames)):
            print(f"[{i}] {probabilities[i]:.6f}, {flags[i]}")

        if total_frames > 10:
            print("...")

    return True


def process_frame_by_frame_demo(input_file, hop_size=256, threshold=0.5):
    """
    Demonstrate frame-by-frame processing (useful for real-time applications).
    """
    print(f"\nFrame-by-frame processing demo:")
    print("-" * 30)

    try:
        with WAVReader(input_file) as wav:
            audio_data = wav.read_audio_data()
    except Exception as e:
        print(f"ERROR reading audio file: {e}")
        return False

    # Initialize VAD
    try:
        vad = ten_vad_python.TenVAD(hop_size=hop_size, threshold=threshold)
    except Exception as e:
        print(f"ERROR initializing VAD: {e}")
        return False

    total_frames = len(audio_data) // hop_size
    voice_count = 0

    print(f"Processing {min(20, total_frames)} frames individually...")

    for i in range(min(20, total_frames)):
        start_idx = i * hop_size
        end_idx = start_idx + hop_size
        frame = audio_data[start_idx:end_idx]

        try:
            probability, flag = vad.process_frame(frame)
            voice_count += flag
            print(f"Frame {i:2d}: prob={probability:.6f}, voice={flag}")
        except Exception as e:
            print(f"ERROR processing frame {i}: {e}")
            return False

    print(f"Voice detected in {voice_count}/{min(20, total_frames)} frames")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="TEN VAD Python Demo - Voice Activity Detection",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python vad_demo.py audio.wav results.txt
  python vad_demo.py audio.wav results.txt --threshold 0.6
  python vad_demo.py audio.wav results.txt --hop-size 512 --threshold 0.4
  python vad_demo.py audio.wav results.txt --frame-demo
        """
    )

    parser.add_argument('input_file', help='Input WAV file path')
    parser.add_argument('output_file', help='Output text file path')
    parser.add_argument('--hop-size', type=int, default=256,
                       help='Hop size (samples per frame, default: 256)')
    parser.add_argument('--threshold', type=float, default=0.5,
                       help='VAD threshold [0.0-1.0] (default: 0.5)')
    parser.add_argument('--frame-demo', action='store_true',
                       help='Also run frame-by-frame processing demo')
    parser.add_argument('--quiet', action='store_true',
                       help='Reduce output verbosity')

    args = parser.parse_args()

    # Validate arguments
    if not os.path.exists(args.input_file):
        print(f"ERROR: Input file not found: {args.input_file}")
        return 1

    if args.hop_size <= 0:
        print(f"ERROR: Invalid hop size: {args.hop_size}")
        return 1

    if not (0.0 <= args.threshold <= 1.0):
        print(f"ERROR: Threshold must be between 0.0 and 1.0: {args.threshold}")
        return 1

    # Create output directory if needed
    output_dir = os.path.dirname(args.output_file)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Process the audio file
    success = process_audio_file(
        args.input_file,
        args.output_file,
        hop_size=args.hop_size,
        threshold=args.threshold,
        verbose=not args.quiet
    )

    if not success:
        return 1

    # Optional frame-by-frame demo
    if args.frame_demo:
        process_frame_by_frame_demo(
            args.input_file,
            hop_size=args.hop_size,
            threshold=args.threshold
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
