# RISC-V Data Memory with Wishbone Bus Interface

## Overview
A 64-bit Data Memory module designed for RISC-V (RV64I) architecture, implemented in SystemVerilog with a Wishbone bus interface. Developed and verified on Xilinx Zybo (xc7z010clg400-1) FPGA.

## Project Structure
- data_mem.sv — Top-level 64-bit data memory
- data_mem_wb.sv — Wishbone bus wrapper
- top_wrapper.sv — FPGA top-level wrapper
- tb_data_mem.sv — Testbench (8 tests)
- zybo_constraints.xdc — Zybo FPGA constraints

## Features
- 64-bit RISC-V RV64I data memory
- All load operations: LB, LH, LW, LD, LBU, LHU, LWU
- All store operations: SB, SH, SW, SD
- Wishbone bus interface
- Misalignment error detection
- Synchronous reset

## Simulation Results
- Test 1 SD/LD — PASS
- Test 2 SW/LW — PASS
- Test 3 SW/LWU — PASS
- Test 4 SH/LH — PASS
- Test 5 SH/LHU — PASS
- Test 6 SB/LB — PASS
- Test 7 SB/LBU — PASS
- Test 8 Misalignment Error — PASS

8/8 Tests Passing

## Tools Used
- Xilinx Vivado 2024.2
- SystemVerilog
- Zybo FPGA (xc7z010clg400-1)

## Implementation
- Synthesis: Complete
- Implementation: Complete
- Timing Constraints: All met
