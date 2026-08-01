// SPDX-License-Identifier: Apache-2.0
`timescale 1ns/1ps

module tb_minimal;
    logic clk = 0;
    // rst_n must start at 0 to ensure all async-reset FFs are properly
    // initialized before any combinational logic evaluates.
    logic rst_n = 0;

    initial begin
        #100;
        forever #10 clk = ~clk;
    end

    initial begin
        #1000;
        rst_n = 1;
    end

    muntjac_core #(
        .DataWidth(64),
        .PhysAddrLen(56)
    ) uut (
        .clk_i(clk),
        .rst_ni(rst_n),
        .mem_a_ready_i(1'b0),
        .mem_a_valid_o(),
        .mem_a_o(),
        .mem_b_ready_o(),
        .mem_b_valid_i(1'b0),
        .mem_b_i(70'b0),
        .mem_c_ready_i(1'b0),
        .mem_c_valid_o(),
        .mem_c_o(),
        .mem_d_ready_o(),
        .mem_d_valid_i(1'b0),
        .mem_d_i(81'b0),
        .mem_e_ready_i(1'b0),
        .mem_e_valid_o(),
        .mem_e_o(),
        .irq_software_m_i(1'b0),
        .irq_timer_m_i(1'b0),
        .irq_external_m_i(1'b0),
        .irq_external_s_i(1'b0),
        .hart_id_i(64'b0),
        .hpm_event_i(10'b0),
        .dbg_o()
    );

endmodule
