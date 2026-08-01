// SPDX-License-Identifier: Apache-2.0

module top_level #(
    parameter RESET_STRATEGY = "NONE",
    parameter memfile = "",
    parameter memsize = 8192,
    parameter [7:0] sim = 8'b0
)
(
    input wire clk,
    input wire reset
);

     // Signals for the 'tb' module interface
    reg [31:0] wb_inputs_adr;
    reg [31:0] wb_inputs_dat;
    reg [3:0] wb_inputs_sel;
    reg wb_inputs_we;
    reg wb_inputs_cyc;
    wire [31:0] wb_outputs_rdt;
    wire wb_outputs_ack;
    wire txd, rxd;

    // Signals for the 'serving' module interface
    wire [31:0] o_wb_adr;
    wire [31:0] o_wb_dat;
    wire [3:0]  o_wb_sel;
    wire        o_wb_we;
    wire        o_wb_stb;
    wire i_timer_irq = 1'b0;

        // Additional connections
    assign wb_inputs_adr = o_wb_adr;
    assign wb_inputs_dat = o_wb_dat;
    assign wb_inputs_sel = o_wb_sel;
    assign wb_inputs_we = o_wb_we;
    assign wb_inputs_cyc = o_wb_stb;

    // Loop the UART back onto itself.
    assign rxd = txd;

    tb my_tb (
        .wb_inputs_adr(wb_inputs_adr),
        .wb_inputs_dat(wb_inputs_dat),
        .wb_inputs_sel(wb_inputs_sel),
        .wb_inputs_we(wb_inputs_we),
        .wb_inputs_cyc(wb_inputs_cyc),
        .rxd(rxd),
        .clk(clk),
        .reset(reset),
        .wb_outputs_rdt(wb_outputs_rdt),
        .wb_outputs_ack(wb_outputs_ack),
        .txd(txd)
    );

    serving #(
        .RESET_STRATEGY(RESET_STRATEGY),
        .memfile(memfile),
        .memsize(memsize),
        .sim(sim[0])
    ) my_serving (
        .i_clk(clk),
        .i_rst(reset),
        .i_timer_irq(i_timer_irq),
        .o_wb_adr(o_wb_adr),
        .o_wb_dat(o_wb_dat),
        .o_wb_sel(o_wb_sel),
        .o_wb_we(o_wb_we),
        .o_wb_stb(o_wb_stb),
        .i_wb_rdt(wb_outputs_rdt),
        .i_wb_ack(wb_outputs_ack)
    );

endmodule
