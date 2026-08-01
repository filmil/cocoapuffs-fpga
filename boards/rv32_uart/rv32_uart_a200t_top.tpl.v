// SPDX-License-Identifier: Apache-2.0

// A top-level module that implements a 32-bit risc-v controller with a connected
// UART peripheral, intended for the Alinx A200T board.
module rv32_uart_a200t_top(
    // The A200T board only has an active-low reset.
    input wire reset_n,

    // Differential clock inputs. These must be reconstructed internally
    // into a single-ended clock signal.  A typical A200T board will have
    // a nominal differential clock input at 200MHz.
    input wire sys_clk_p,
    input wire sys_clk_n,

    // Led outputs for visual success control.
    output wire led1,
    output wire led2,
    output wire led3,
    output wire led4,

    // UART peripheral serial interface. In the Alinx A200T, these are
    // connected to a USB port via USB-to-Serial converter chip.
    output wire tx,
    input wire rx
);

     // Signals for the 'vhdl_top' module interface
    wire [31:0] wb_inputs_adr;
    wire [31:0] wb_inputs_dat;
    wire [3:0] wb_inputs_sel;
    wire wb_inputs_we;
    wire wb_inputs_cyc;
    wire [31:0] wb_outputs_rdt;
    wire wb_outputs_ack;
    wire clk100Mhz, reset;

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

    vhdl_top top (
        .clk(clk100Mhz), // Out. Generated.
        .reset_n(reset_n), // In.
        .reset(reset), // Out. Generated.
        .sys_clk_p(sys_clk_p), // In.
        .sys_clk_n(sys_clk_n), // In.

        .adr(wb_inputs_adr), // In.
        .dat(wb_inputs_dat),
        .sel(wb_inputs_sel),
        .we(wb_inputs_we),
        .cyc(wb_inputs_cyc),
        .rdt(wb_outputs_rdt), // Out.
        .ack(wb_outputs_ack),

        .led1(led1),
        .led2(led2),
        .led3(led3),
        .led4(led4),

        .uart1_txd(tx), // Out.
        .uart1_rxd(rx) // In.

    );

    serving #(
        .RESET_STRATEGY({{RESET_STRATEGY}}),
        .memfile({{MEMFILE}}),
        .memsize({{MEMSIZE}}),
        .sim({{SIM}})
    ) my_serving (
        .i_clk(clk100Mhz),
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
