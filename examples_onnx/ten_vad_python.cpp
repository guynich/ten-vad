//
// Copyright © 2025 Agora
// This file is part of TEN Framework, an open source project.
// Licensed under the Apache License, Version 2.0, with certain conditions.
// Refer to the "LICENSE" file in the root directory for more information.
//
// pybind11 wrapper with C++ class interface
//

#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>
#include <pybind11/stl.h>
#include <vector>
#include <memory>
#include <stdexcept>

extern "C" {
#include "ten_vad.h"
}

namespace py = pybind11;

class TenVAD {
private:
    ten_vad_handle_t handle_;
    size_t hop_size_;
    float threshold_;
    bool initialized_;

public:
    TenVAD(size_t hop_size = 256, float threshold = 0.5f)
        : handle_(nullptr), hop_size_(hop_size), threshold_(threshold), initialized_(false) {
        if (hop_size == 0) {
            throw std::invalid_argument("hop_size must be greater than 0");
        }
        if (threshold < 0.0f || threshold > 1.0f) {
            throw std::invalid_argument("threshold must be between 0.0 and 1.0");
        }

        int result = ten_vad_create(&handle_, hop_size_, threshold_);
        if (result != 0) {
            throw std::runtime_error("Failed to create TEN VAD instance");
        }
        initialized_ = true;
    }

    ~TenVAD() {
        if (initialized_ && handle_) {
            ten_vad_destroy(&handle_);
        }
    }

    // Disable copy constructor and assignment operator
    TenVAD(const TenVAD&) = delete;
    TenVAD& operator=(const TenVAD&) = delete;

    // Enable move constructor and assignment operator
    TenVAD(TenVAD&& other) noexcept
        : handle_(other.handle_), hop_size_(other.hop_size_),
          threshold_(other.threshold_), initialized_(other.initialized_) {
        other.handle_ = nullptr;
        other.initialized_ = false;
    }

    TenVAD& operator=(TenVAD&& other) noexcept {
        if (this != &other) {
            if (initialized_ && handle_) {
                ten_vad_destroy(&handle_);
            }
            handle_ = other.handle_;
            hop_size_ = other.hop_size_;
            threshold_ = other.threshold_;
            initialized_ = other.initialized_;
            other.handle_ = nullptr;
            other.initialized_ = false;
        }
        return *this;
    }

    std::tuple<float, int> process_frame(py::array_t<int16_t> audio_data) {
        if (!initialized_) {
            throw std::runtime_error("VAD instance not initialized");
        }

        py::buffer_info buf = audio_data.request();

        if (buf.ndim != 1) {
            throw std::invalid_argument("Audio data must be 1-dimensional");
        }

        if (buf.size != static_cast<ssize_t>(hop_size_)) {
            throw std::invalid_argument("Audio data size must equal hop_size (" +
                                      std::to_string(hop_size_) + ")");
        }

        const int16_t* data = static_cast<const int16_t*>(buf.ptr);
        float probability;
        int flag;

        int result = ten_vad_process(handle_, data, hop_size_, &probability, &flag);
        if (result != 0) {
            throw std::runtime_error("VAD processing failed");
        }

        return std::make_tuple(probability, flag);
    }

    std::tuple<py::array_t<float>, py::array_t<int>> process_audio(py::array_t<int16_t> audio_data) {
        if (!initialized_) {
            throw std::runtime_error("VAD instance not initialized");
        }

        py::buffer_info buf = audio_data.request();

        if (buf.ndim != 1) {
            throw std::invalid_argument("Audio data must be 1-dimensional");
        }

        size_t total_samples = buf.size;
        size_t num_frames = total_samples / hop_size_;

        if (total_samples % hop_size_ != 0) {
            throw std::invalid_argument("Audio data length must be divisible by hop_size");
        }

        const int16_t* data = static_cast<const int16_t*>(buf.ptr);

        // Create output arrays
        auto probabilities = py::array_t<float>(num_frames);
        auto flags = py::array_t<int>(num_frames);

        py::buffer_info prob_buf = probabilities.request();
        py::buffer_info flag_buf = flags.request();

        float* prob_ptr = static_cast<float*>(prob_buf.ptr);
        int* flag_ptr = static_cast<int*>(flag_buf.ptr);

        // Process each frame
        for (size_t i = 0; i < num_frames; ++i) {
            const int16_t* frame_data = data + (i * hop_size_);

            int result = ten_vad_process(handle_, frame_data, hop_size_,
                                       &prob_ptr[i], &flag_ptr[i]);
            if (result != 0) {
                throw std::runtime_error("VAD processing failed at frame " + std::to_string(i));
            }
        }

        return std::make_tuple(probabilities, flags);
    }

    size_t get_hop_size() const { return hop_size_; }
    float get_threshold() const { return threshold_; }
    bool is_initialized() const { return initialized_; }

    std::string get_version() const {
        return std::string(ten_vad_get_version());
    }
};

PYBIND11_MODULE(ten_vad_python, m) {
    m.doc() = "TEN VAD Python bindings - Voice Activity Detection";

    py::class_<TenVAD>(m, "TenVAD")
        .def(py::init<size_t, float>(),
             "Create TEN VAD instance",
             py::arg("hop_size") = 256,
             py::arg("threshold") = 0.5f)
        .def("process_frame", &TenVAD::process_frame,
             "Process a single audio frame",
             py::arg("audio_data"))
        .def("process_audio", &TenVAD::process_audio,
             "Process entire audio buffer",
             py::arg("audio_data"))
        .def("get_hop_size", &TenVAD::get_hop_size,
             "Get the hop size")
        .def("get_threshold", &TenVAD::get_threshold,
             "Get the VAD threshold")
        .def("is_initialized", &TenVAD::is_initialized,
             "Check if VAD is initialized")
        .def("get_version", &TenVAD::get_version,
             "Get TEN VAD version");

    m.def("get_version", []() {
        return std::string(ten_vad_get_version());
    }, "Get TEN VAD library version");
}
