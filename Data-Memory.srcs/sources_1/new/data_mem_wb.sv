`timescale 1ns / 1ps

// Wishbone Bus Interface wrapper for data_mem (RV64)
module data_mem_wb #(
    parameter int dwidth      = 64,
    parameter int awidth      = 64,
    parameter int instr_width = 32,
    parameter int mdepth      = 256
)(
    // Wishbone Slave Interface
    input  logic                   clk_i,       // Clock
    input  logic                   rst_i,       // Reset (active high)
    
    // Wishbone signals
    input  logic                   wb_cyc_i,    // Cycle valid
    input  logic                   wb_stb_i,    // Strobe
    input  logic                   wb_we_i,     // Write enable
    input  logic [awidth-1:0]      wb_adr_i,    // Address
    input  logic [dwidth-1:0]      wb_dat_i,    // Data in (write)
    input  logic [dwidth/8-1:0]    wb_sel_i,    // Byte select
    input  logic [instr_width-1:0] wb_instr_i,  // Instruction
    output logic [dwidth-1:0]      wb_dat_o,    // Data out (read)
    output logic                   wb_ack_o,    // Acknowledge
    output logic                   wb_err_o,    // Error
    output logic                   wb_stall_o   // Stall
);

    // ------------------------------
    // Internal signals
    // ------------------------------
    logic wrEn_s;
    logic rdEn_s;
    logic wb_valid;

    // Valid transaction
    assign wb_valid = wb_cyc_i & wb_stb_i;

    // Write enable: valid + write
    assign wrEn_s = wb_valid & wb_we_i;

    // Read enable: valid + read
    assign rdEn_s = wb_valid & ~wb_we_i;

    // No stall (single cycle response)
    assign wb_stall_o = 1'b0;

    // ------------------------------
    // ACK generation (1 cycle later)
    // ------------------------------
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i)
            wb_ack_o <= 1'b0;
        else
            wb_ack_o <= wb_valid;  // ACK one cycle after request
    end

    // ------------------------------
    // Error generation
    // Trigger error on misaligned access
    // ------------------------------
    always_comb begin
        wb_err_o = 1'b0;

        if (wb_valid) begin
            case (wb_instr_i[14:12]) // func3
                3'b001: // LH/SH - must be 2-byte aligned
                    wb_err_o = wb_adr_i[0];
                3'b010: // LW/SW - must be 4-byte aligned
                    wb_err_o = |wb_adr_i[1:0];
                3'b011: // LD/SD - must be 8-byte aligned
                    wb_err_o = |wb_adr_i[2:0];
                default:
                    wb_err_o = 1'b0;
            endcase
        end
    end

    // ------------------------------
    // Data memory instance
    // ------------------------------
    data_mem #(
        .dwidth     (dwidth),
        .awidth     (awidth),
        .instr_width(instr_width),
        .mdepth     (mdepth)
    ) u_data_mem (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .wrEn_i (wrEn_s),
        .rdEn_i (rdEn_s),
        .addr_i (wb_adr_i),
        .instr_i(wb_instr_i),
        .data_i (wb_dat_i),
        .data_o (wb_dat_o)
    );

endmodule