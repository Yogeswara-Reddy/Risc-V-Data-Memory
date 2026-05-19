`timescale 1ns / 1ps

module top_wrapper (
    input  logic clk_i,
    input  logic rst_i,
    output logic led_o      // ✅ small output to keep design alive
);

    // Internal Wishbone signals
    logic        wb_cyc;
    logic        wb_stb;
    logic        wb_we;
    logic [63:0] wb_adr;
    logic [63:0] wb_dat_i;
    logic [7:0]  wb_sel;
    logic [31:0] wb_instr;
    logic [63:0] wb_dat_o;
    logic        wb_ack;
    logic        wb_err;
    logic        wb_stall;

    // Wishbone memory instance
    data_mem_wb #(
        .dwidth     (64),
        .awidth     (64),
        .instr_width(32),
        .mdepth     (256)
    ) u_data_mem_wb (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .wb_cyc_i   (wb_cyc),
        .wb_stb_i   (wb_stb),
        .wb_we_i    (wb_we),
        .wb_adr_i   (wb_adr),
        .wb_dat_i   (wb_dat_i),
        .wb_sel_i   (wb_sel),
        .wb_instr_i (wb_instr),
        .wb_dat_o   (wb_dat_o),
        .wb_ack_o   (wb_ack),
        .wb_err_o   (wb_err),
        .wb_stall_o (wb_stall)
    );

    assign wb_cyc   = 1'b1;
    assign wb_stb   = 1'b1;
    assign wb_we    = 1'b0;
    assign wb_adr   = 64'h08;
    assign wb_dat_i = '0;
    assign wb_sel   = '1;
    assign wb_instr = 32'b000000000000_00000_011_00000_0000011; // LD

    // LED shows ACK signal - keeps design alive
    assign led_o = wb_ack;

endmodule