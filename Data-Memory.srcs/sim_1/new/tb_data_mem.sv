`timescale 1ns / 1ps

module tb_data_mem_wb;

    // ------------------------------
    // Parameters
    // ------------------------------
    parameter int dwidth      = 64;
    parameter int awidth      = 64;
    parameter int instr_width = 32;
    parameter int mdepth      = 256;

    // ------------------------------
    // Clock & Reset
    // ------------------------------
    logic clk;
    logic rst;

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // ------------------------------
    // Wishbone signals
    // ------------------------------
    logic                   wb_cyc;
    logic                   wb_stb;
    logic                   wb_we;
    logic [awidth-1:0]      wb_adr;
    logic [dwidth-1:0]      wb_dat_i;
    logic [dwidth/8-1:0]    wb_sel;
    logic [instr_width-1:0] wb_instr;
    logic [dwidth-1:0]      wb_dat_o;
    logic                   wb_ack;
    logic                   wb_err;
    logic                   wb_stall;

    // ------------------------------
    // DUT instantiation
    // ------------------------------
    data_mem_wb #(
        .dwidth     (dwidth),
        .awidth     (awidth),
        .instr_width(instr_width),
        .mdepth     (mdepth)
    ) dut (
        .clk_i      (clk),
        .rst_i      (rst),
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

    // ------------------------------
    // Tasks
    // ------------------------------

    // WRITE task
    task wb_write(
        input [awidth-1:0]      addr,
        input [dwidth-1:0]      data,
        input [instr_width-1:0] instr
    );
        @(posedge clk);
        wb_cyc   <= 1;
        wb_stb   <= 1;
        wb_we    <= 1;
        wb_adr   <= addr;
        wb_dat_i <= data;
        wb_instr <= instr;
        wb_sel   <= '1;
        @(posedge clk);
        wait(wb_ack);
        @(posedge clk);
        wb_cyc   <= 0;
        wb_stb   <= 0;
        wb_we    <= 0;
    endtask

    // READ task
    task wb_read(
        input  [awidth-1:0]      addr,
        input  [instr_width-1:0] instr,
        output [dwidth-1:0]      data
    );
        @(posedge clk);
        wb_cyc   <= 1;
        wb_stb   <= 1;
        wb_we    <= 0;
        wb_adr   <= addr;
        wb_instr <= instr;
        wb_sel   <= '1;
        @(posedge clk);
        wait(wb_ack);
        data     = wb_dat_o;
        @(posedge clk);
        wb_cyc   <= 0;
        wb_stb   <= 0;
    endtask

    // ------------------------------
    // Instruction encodings
    // ------------------------------
    // Store instructions
    localparam logic [31:0] SB_INSTR = 32'b0000000_00000_00000_000_00000_0100011; // SB
    localparam logic [31:0] SH_INSTR = 32'b0000000_00000_00000_001_00000_0100011; // SH
    localparam logic [31:0] SW_INSTR = 32'b0000000_00000_00000_010_00000_0100011; // SW
    localparam logic [31:0] SD_INSTR = 32'b0000000_00000_00000_011_00000_0100011; // SD

    // Load instructions
    localparam logic [31:0] LB_INSTR  = 32'b000000000000_00000_000_00000_0000011; // LB
    localparam logic [31:0] LH_INSTR  = 32'b000000000000_00000_001_00000_0000011; // LH
    localparam logic [31:0] LW_INSTR  = 32'b000000000000_00000_010_00000_0000011; // LW
    localparam logic [31:0] LD_INSTR  = 32'b000000000000_00000_011_00000_0000011; // LD
    localparam logic [31:0] LBU_INSTR = 32'b000000000000_00000_100_00000_0000011; // LBU
    localparam logic [31:0] LHU_INSTR = 32'b000000000000_00000_101_00000_0000011; // LHU
    localparam logic [31:0] LWU_INSTR = 32'b000000000000_00000_110_00000_0000011; // LWU

    // ------------------------------
    // Test variables
    // ------------------------------
    logic [dwidth-1:0] read_data;
    int pass_count = 0;
    int fail_count = 0;

    // ------------------------------
    // Check task
    // ------------------------------
    task check(
        input string       test_name,
        input [dwidth-1:0] actual,
        input [dwidth-1:0] expected
    );
        if (actual === expected) begin
            $display("✅ PASS: %s | Got: 0x%016h", test_name, actual);
            pass_count++;
        end else begin
            $display("❌ FAIL: %s | Got: 0x%016h | Expected: 0x%016h",
                      test_name, actual, expected);
            fail_count++;
        end
    endtask

    // ------------------------------
    // Main test
    // ------------------------------
    initial begin
        // Init signals
        rst      = 1;
        wb_cyc   = 0;
        wb_stb   = 0;
        wb_we    = 0;
        wb_adr   = '0;
        wb_dat_i = '0;
        wb_sel   = '0;
        wb_instr = '0;

        // Reset for 3 cycles
        repeat(3) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);

        $display("\n========== STARTING TESTS ==========\n");

        // --------------------------
        // Test 1: SD (Store Double)
        // --------------------------
        $display("--- Test 1: SD/LD ---");
        wb_write(64'h00, 64'hDEADBEEFCAFEBABE, SD_INSTR);
        wb_read (64'h00, LD_INSTR, read_data);
        check("SD/LD", read_data, 64'hDEADBEEFCAFEBABE);

        // --------------------------
        // Test 2: SW (Store Word)
        // --------------------------
        $display("--- Test 2: SW/LW ---");
        wb_write(64'h08, 64'hFFFFFFFF87654321, SW_INSTR);
        wb_read (64'h08, LW_INSTR, read_data);
        check("SW/LW", read_data, 64'hFFFFFFFF87654321); // sign extended

        // --------------------------
        // Test 3: LWU (Load Word Unsigned)
        // --------------------------
        $display("--- Test 3: SW/LWU ---");
        wb_read(64'h08, LWU_INSTR, read_data);
        check("SW/LWU", read_data, 64'h0000000087654321); // zero extended

        // --------------------------
        // Test 4: SH (Store Half)
        // --------------------------
        $display("--- Test 4: SH/LH ---");
        wb_write(64'h10, 64'hABCD, SH_INSTR);
        wb_read (64'h10, LH_INSTR, read_data);
        check("SH/LH", read_data, 64'hFFFFFFFFFFFFABCD); // sign extended

        // --------------------------
        // Test 5: LHU (Load Half Unsigned)
        // --------------------------
        $display("--- Test 5: SH/LHU ---");
        wb_read(64'h10, LHU_INSTR, read_data);
        check("SH/LHU", read_data, 64'h000000000000ABCD); // zero extended

        // --------------------------
        // Test 6: SB (Store Byte)
        // --------------------------
        $display("--- Test 6: SB/LB ---");
        wb_write(64'h18, 64'hFF, SB_INSTR);
        wb_read (64'h18, LB_INSTR, read_data);
        check("SB/LB", read_data, 64'hFFFFFFFFFFFFFFFF); // sign extended

        // --------------------------
        // Test 7: LBU (Load Byte Unsigned)
        // --------------------------
        $display("--- Test 7: SB/LBU ---");
        wb_read(64'h18, LBU_INSTR, read_data);
        check("SB/LBU", read_data, 64'h00000000000000FF); // zero extended

        // --------------------------
        // Test 8: Misalignment error
        // --------------------------
       $display("--- Test 8: Misalignment Error ---");
@(posedge clk);
wb_cyc   <= 1;
wb_stb   <= 1;
wb_we    <= 1;
wb_adr   <= 64'h01; // misaligned for SH
wb_instr <= SH_INSTR;
wb_dat_i <= 64'hABCD;
wb_sel   <= '1;
@(posedge clk);
check("Misalignment SH", {63'b0, wb_err}, 64'h1); // 
wb_cyc <= 0;
wb_stb <= 0;

        // --------------------------
        // Final Results
        // --------------------------
        repeat(2) @(posedge clk);
        $display("\n========== RESULTS ==========");
        $display("✅ PASSED: %0d", pass_count);
        $display("❌ FAILED: %0d", fail_count);
        $display("==============================\n");

        $finish;
    end

endmodule