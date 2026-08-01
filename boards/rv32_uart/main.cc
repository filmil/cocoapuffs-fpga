// SPDX-License-Identifier: Apache-2.0

#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtop_level.h"

#include <unistd.h>

vluint64_t sim_time = 0;

int main(int argc, char** argv, char** env) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    char buf[1000];
    auto _ = getcwd(buf, sizeof(buf));
    std::cout << "Work directory: " << buf << std::endl;

    if (argc != 3) {
        std::cerr << "Usage: sim <filename> <sim_time_in_ps>" << std::endl;
        exit(-1);
    }

    Vtop_level dut;
    VerilatedVcdC m_trace;
    dut.trace(&m_trace, 5);
    m_trace.open(argv[1]);
    vluint64_t max_sim_time_ps = std::atoll(argv[2]);
    std::cout << "Simulating for: " << max_sim_time_ps << " ps" << std::endl;

    // A reset is needed first.
    while (sim_time < 100) {
        dut.clk ^= 1;
        dut.reset = 1;
        dut.eval();
        m_trace.dump(sim_time);
        sim_time++;
    }

    // Simulate the rest.
    while (sim_time < max_sim_time_ps) {
        dut.reset = 0;
        dut.clk ^= 1;
        dut.eval();
        m_trace.dump(sim_time);
        sim_time++;
    }

    m_trace.close();
    exit(EXIT_SUCCESS);
}
