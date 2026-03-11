#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>

#include "VPipelineNTT_top.h"
#include "verilated.h"

namespace {

constexpr int kLaneCount = 128;
constexpr int kLatencyCycles = 36;

vluint64_t g_main_time = 0;

double sc_time_stamp() { return static_cast<double>(g_main_time); }

void tick(VPipelineNTT_top& dut) {
    dut.clk = 0;
    dut.eval();
    ++g_main_time;

    dut.clk = 1;
    dut.eval();
    ++g_main_time;
}

bool load_hex_words(const char* path, std::array<uint32_t, kLaneCount>& words) {
    std::ifstream ifs(path);
    if (!ifs.is_open()) {
        std::cerr << "Failed to open input file: " << path << "\n";
        return false;
    }

    std::string token;
    int idx = 0;
    while (idx < kLaneCount && (ifs >> token)) {
        char* end_ptr = nullptr;
        const unsigned long value = std::strtoul(token.c_str(), &end_ptr, 16);
        if (end_ptr == token.c_str() || *end_ptr != '\0') {
            std::cerr << "Invalid hex token at index " << idx << ": " << token << "\n";
            return false;
        }
        words[idx++] = static_cast<uint32_t>(value);
    }

    if (idx != kLaneCount) {
        std::cerr << "Expected " << kLaneCount << " words but got " << idx << "\n";
        return false;
    }
    return true;
}

bool parse_positive_int(const char* text, int& out) {
    char* end_ptr = nullptr;
    const long value = std::strtol(text, &end_ptr, 10);
    if (end_ptr == text || *end_ptr != '\0' || value <= 0) {
        return false;
    }
    out = static_cast<int>(value);
    return true;
}

}  // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    std::array<uint32_t, kLaneCount> in_words{};
    int cycles = kLatencyCycles;
    bool use_default_input = true;

    int arg_idx = 1;
    if (arg_idx < argc) {
        int parsed_cycles = 0;
        if (parse_positive_int(argv[arg_idx], parsed_cycles)) {
            cycles = parsed_cycles;
            ++arg_idx;
        } else {
            if (!load_hex_words(argv[arg_idx], in_words)) {
                return 1;
            }
            use_default_input = false;
            ++arg_idx;
            if (arg_idx < argc) {
                if (!parse_positive_int(argv[arg_idx], cycles)) {
                    std::cerr << "Cycle count must be a positive integer.\n";
                    return 1;
                }
                ++arg_idx;
            }
        }
    }

    if (arg_idx != argc) {
        std::cerr << "Usage: " << argv[0]
                  << " [input_hex_file] [cycles]\n"
                  << "   or: " << argv[0] << " [cycles]\n";
        return 1;
    }

    if (use_default_input) {
        for (int i = 0; i < kLaneCount; ++i) {
            in_words[i] = static_cast<uint32_t>(i);
        }
    }

    VPipelineNTT_top dut;
    for (int i = 0; i < kLaneCount; ++i) {
        dut.in[i] = in_words[i];
    }

    dut.eval();
    for (int c = 0; c < cycles; ++c) {
        tick(dut);
    }

    for (int i = 0; i < kLaneCount; ++i) {
        std::printf("%d\n", static_cast<int32_t>(dut.out[i]));
    }

    return 0;
}
