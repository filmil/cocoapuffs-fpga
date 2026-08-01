module muntjac_core_wrapper (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic mem_a_ready_i,
    output logic mem_a_valid_o,
    output logic [142:0] mem_a_o,

    output logic mem_b_ready_o,
    input  logic mem_b_valid_i,
    input  logic [69:0] mem_b_i,

    input  logic mem_c_ready_i,
    output logic mem_c_valid_o,
    output logic [134:0] mem_c_o,

    output logic mem_d_ready_o,
    input  logic mem_d_valid_i,
    input  logic [80:0] mem_d_i,

    input  logic mem_e_ready_i,
    output logic mem_e_valid_o,
    output logic [0:0] mem_e_o,

    input  logic irq_software_m_i,
    input  logic irq_timer_m_i,
    input  logic irq_external_m_i,
    input  logic irq_external_s_i,

    input  logic [63:0] hart_id_i,

    input  logic [9:0] hpm_event_i

    // Ignore dbg_o as it contains a struct which vivado VHDL cannot instantiate
);

    muntjac_core core_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mem_a_ready_i(mem_a_ready_i),
        .mem_a_valid_o(mem_a_valid_o),
        .mem_a_o(mem_a_o),
        .mem_b_ready_o(mem_b_ready_o),
        .mem_b_valid_i(mem_b_valid_i),
        .mem_b_i(mem_b_i),
        .mem_c_ready_i(mem_c_ready_i),
        .mem_c_valid_o(mem_c_valid_o),
        .mem_c_o(mem_c_o),
        .mem_d_ready_o(mem_d_ready_o),
        .mem_d_valid_i(mem_d_valid_i),
        .mem_d_i(mem_d_i),
        .mem_e_ready_i(mem_e_ready_i),
        .mem_e_valid_o(mem_e_valid_o),
        .mem_e_o(mem_e_o),
        .irq_software_m_i(irq_software_m_i),
        .irq_timer_m_i(irq_timer_m_i),
        .irq_external_m_i(irq_external_m_i),
        .irq_external_s_i(irq_external_s_i),
        .hart_id_i(hart_id_i),
        .hpm_event_i(hpm_event_i),
        .dbg_o()
    );

endmodule
