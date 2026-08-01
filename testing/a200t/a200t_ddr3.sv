// SPDX-License-Identifier: Apache-2.0

`timescale 1ps / 1ps

// The DDR3 memory peripheral, as installed on the Alinx A200T board.
module a200t_ddr3 (
    inout [3:0] ddr3_dqs,
    inout [3:0] ddr3_dqs_n,
    inout [31:0] ddr3_dq,

    input [3:0] ddr3_dm,
    input [14:0] ddr3_a,
    input [2:0] ddr3_ba,
    input ddr3_ras,
    input ddr3_cas,
    input ddr3_we,
    input ddr3_odt,
    input clk_n,
    input clk_p,
    input ddr3_cke,
    input rst_n,

    // What are these?
    output [3:0] tdqs_n,
    input cs_n
);

ddr3 ddr3_0 (
    .ck(clk_p),
    .ck_n(clk_n),
    .cke(ddr3_cke),
    .cs_n(cs_n),
    .ras_n(ddr3_ras),
    .cas_n(ddr3_cas),
    .we_n(ddr3_we),
    .ba(ddr3_ba),
    .addr(ddr3_a),
    .dq(ddr3_dq[15:0]),
    .dqs(ddr3_dqs[1:0]),
    .dqs_n(ddr3_dqs_n[1:0]),
    .odt(ddr3_odt),
    .rst_n(rst_n),

    // This is an output, but the simulator model does not seem to use this,
    // and keeps it at 'z' at all times.
    .tdqs_n(tdqs_n[1:0]),
    // From micron testbenches, it seems that ddr3_dm should be wired through
    // to here.
    .dm_tdqs(ddr3_dm[1:0])
);

ddr3 ddr3_1 (
    .ck(clk_p),
    .ck_n(clk_n),
    .cke(ddr3_cke),
    .cs_n(cs_n),
    .ras_n(ddr3_ras),
    .cas_n(ddr3_cas),
    .we_n(ddr3_we),
    .ba(ddr3_ba),
    .addr(ddr3_a),
    .dq(ddr3_dq[31:16]),
    .dqs(ddr3_dqs[3:2]),
    .dqs_n(ddr3_dqs_n[3:2]),
    .odt(ddr3_odt),
    .rst_n(rst_n),

    // See the same pins on ddr3_0 above.
    .tdqs_n(tdqs_n[3:2]),
    .dm_tdqs(ddr3_dm[3:2])
);

endmodule
