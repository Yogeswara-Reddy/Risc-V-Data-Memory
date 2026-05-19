`timescale 1ns / 1ps

// Top-level data memory with load/store handling for RV64
module data_mem #(
    parameter int dwidth      = 64,
    parameter int awidth      = 64,
    parameter int instr_width = 32,
    parameter int mdepth      = 256
)(
    input  logic                   clk_i,
    input  logic                   rst_i,        
    input  logic                   wrEn_i,
    input  logic                   rdEn_i,
    input  logic [awidth-1:0]      addr_i,
    input  logic [instr_width-1:0] instr_i,
    input  logic [dwidth-1:0]      data_i,
    output logic [dwidth-1:0]      data_o
);

    // ------------------------------
    // Internal signals
    // ------------------------------
    localparam int ADDR_BITS = $clog2(mdepth); // 

    logic [dwidth-1:0] ram_s [0:mdepth-1];

    integer i;
    initial begin
        for (i = 0; i < mdepth; i++) begin
            ram_s[i] = '0;
        end
    end

    logic [dwidth-1:0] dataRd_s;
    logic [dwidth-1:0] dataWr_s;

    logic [6:0] opcode_s;
    logic [2:0] func3_s;

    assign opcode_s = instr_i[6:0];
    assign func3_s  = instr_i[14:12];

    // ------------------------------
    // Combinational read
    // use ADDR_BITS to limit address range
    // ------------------------------
    always_comb begin
        dataRd_s = ram_s[addr_i[ADDR_BITS+2:3]];
    end

    // ------------------------------
    // Load path
    // ------------------------------
    load_block #(
        .dwidth(dwidth),
        .awidth(awidth),
        .instr_width(instr_width)
    ) u_load_block (
        .rdEn_i   (rdEn_i),
        .opcoder_s(opcode_s),
        .func3r_s (func3_s),
        .addr_i   (addr_i),
        .dataRd_s (dataRd_s),
        .data_o   (data_o)
    );

    // ------------------------------
    // Store path
    // ------------------------------
    store_block #(
        .dwidth(dwidth),
        .awidth(awidth),
        .instr_width(instr_width)
    ) u_store_block (
        .we_s     (wrEn_i),
        .opcode_s (opcode_s),
        .func3_s  (func3_s),
        .addr_s   (addr_i),
        .dataw_s  (data_i),
        .prev_data(dataRd_s),
        .dataWr_s (dataWr_s)
    );

    // ------------------------------
    // Write to memory
    // reset support
    // ------------------------------
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            for (int j = 0; j < mdepth; j++) begin
                ram_s[j] <= '0;
            end
        end else if (wrEn_i && opcode_s == 7'b0100011) begin
            ram_s[addr_i[ADDR_BITS+2:3]] <= dataWr_s;
        end
    end

endmodule


// ---------------------------------------------------------
// Load block : handles LB/LH/LW/LD and unsigned variants
// ---------------------------------------------------------
module load_block #(
    parameter int dwidth      = 64,
    parameter int awidth      = 64,
    parameter int instr_width = 32
)(
    input  logic                   rdEn_i,
    input  logic [6:0]             opcoder_s,
    input  logic [2:0]             func3r_s,
    input  logic [awidth-1:0]      addr_i,
    input  logic [dwidth-1:0]      dataRd_s,
    output logic [dwidth-1:0]      data_o
);
    logic [2:0] byte_off;
    logic [1:0] half_off;
    logic       word_off;

    logic [7:0]  sel_byte;
    logic [15:0] sel_half;
    logic [31:0] sel_word;

    assign byte_off = addr_i[2:0];
    assign half_off = addr_i[2:1];
    assign word_off = addr_i[2];

    always_comb begin
        // default to zero when not reading
        data_o   = '0;
        sel_byte = 8'b0;
        sel_half = 16'b0;
        sel_word = 32'b0;

        // select byte
        unique case (byte_off)
            3'd0: sel_byte = dataRd_s[7:0];
            3'd1: sel_byte = dataRd_s[15:8];
            3'd2: sel_byte = dataRd_s[23:16];
            3'd3: sel_byte = dataRd_s[31:24];
            3'd4: sel_byte = dataRd_s[39:32];
            3'd5: sel_byte = dataRd_s[47:40];
            3'd6: sel_byte = dataRd_s[55:48];
            3'd7: sel_byte = dataRd_s[63:56];
            default: sel_byte = 8'b0;
        endcase

        // select half-word
        unique case (half_off)
            2'd0: sel_half = dataRd_s[15:0];
            2'd1: sel_half = dataRd_s[31:16];
            2'd2: sel_half = dataRd_s[47:32];
            2'd3: sel_half = dataRd_s[63:48];
            default: sel_half = 16'b0;
        endcase

        // select word
        sel_word = word_off ? dataRd_s[63:32] : dataRd_s[31:0];

        // output zero when rdEn_i is low
        if (rdEn_i && opcoder_s == 7'b0000011) begin
            unique case (func3r_s)
                3'b000: data_o = {{56{sel_byte[7]}}, sel_byte};  // LB
                3'b100: data_o = {56'b0, sel_byte};              // LBU
                3'b001: data_o = {{48{sel_half[15]}}, sel_half}; // LH
                3'b101: data_o = {48'b0, sel_half};              // LHU
                3'b010: data_o = {{32{sel_word[31]}}, sel_word}; // LW
                3'b110: data_o = {32'b0, sel_word};              // LWU
                3'b011: data_o = dataRd_s;                       // LD
                default: data_o = '0;
            endcase
        end
    end

endmodule


// ---------------------------------------------------------
// Store block : handles SB/SH/SW/SD
// ---------------------------------------------------------
module store_block #(
    parameter int dwidth      = 64,
    parameter int awidth      = 64,
    parameter int instr_width = 32
)(
    input  logic                   we_s,
    input  logic [6:0]             opcode_s,
    input  logic [2:0]             func3_s,
    input  logic [awidth-1:0]      addr_s,
    input  logic [dwidth-1:0]      dataw_s,
    input  logic [dwidth-1:0]      prev_data,
    output logic [dwidth-1:0]      dataWr_s
);

    logic [2:0] byte_off;
    logic [1:0] half_off;
    logic       word_off;

    assign byte_off = addr_s[2:0];
    assign half_off = addr_s[2:1];
    assign word_off = addr_s[2];

    always_comb begin
        dataWr_s = prev_data;

        if (we_s && opcode_s == 7'b0100011) begin
            unique case (func3_s)
                3'b000: begin // SB
                    unique case (byte_off)
                        3'd0: dataWr_s[7:0]   = dataw_s[7:0];
                        3'd1: dataWr_s[15:8]  = dataw_s[7:0];
                        3'd2: dataWr_s[23:16] = dataw_s[7:0];
                        3'd3: dataWr_s[31:24] = dataw_s[7:0];
                        3'd4: dataWr_s[39:32] = dataw_s[7:0];
                        3'd5: dataWr_s[47:40] = dataw_s[7:0];
                        3'd6: dataWr_s[55:48] = dataw_s[7:0];
                        3'd7: dataWr_s[63:56] = dataw_s[7:0];
                        default: ;
                    endcase
                end

                3'b001: begin // SH
                    unique case (half_off)
                        2'd0: dataWr_s[15:0]  = dataw_s[15:0];
                        2'd1: dataWr_s[31:16] = dataw_s[15:0];
                        2'd2: dataWr_s[47:32] = dataw_s[15:0];
                        2'd3: dataWr_s[63:48] = dataw_s[15:0];
                        default: ;
                    endcase
                end

                3'b010: begin // SW
                    if (!word_off)
                        dataWr_s[31:0]  = dataw_s[31:0];
                    else
                        dataWr_s[63:32] = dataw_s[31:0];
                end

                3'b011: begin // SD
                    dataWr_s = dataw_s;
                end

                // keep prev_data instead of dataw_s
                default: dataWr_s = prev_data;
            endcase
        end
    end

endmodule