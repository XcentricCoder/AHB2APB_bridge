# AHB-to-APB Pipelined Bridge RTL

## Overview

This repository contains a **Verilog RTL implementation of an AHB-to-APB bridge** with pipelined write support.  
It is designed to interface a **high-performance AHB bus** with a **simpler APB peripheral bus**, supporting:

- Single reads and writes
- Back-to-back pipelined writes
- Proper APB 2-phase handshake (setup & enable)
- Stable data/address buffering for pipelined transactions

The design is synthesizable and fully compatible with standard AHB and APB bus protocols.

---

## Repository Structure

- bridge_rtl.v (**AHB-to-APB bridge RTL**)
- bridge_tb.v (**Testbench for functional verification**)
- README.md (**Project description and usage**)


---

## Module Interface

### **Inputs**

| Signal     | Width | Description |
|-----------|-------|-------------|
| `hclk`    | 1     | AHB clock |
| `hresetn` | 1     | Active-low reset |
| `hselapb` | 1     | AHB select signal for APB bridge |
| `hwrite`  | 1     | Indicates AHB write transfer |
| `htrans`  | 2     | Transfer type (IDLE, BUSY, NONSEQ, SEQ) |
| `haddr`   | 32    | AHB address bus |
| `hwdata`  | 32    | AHB write data bus |
| `prdata`  | 32    | APB read data from peripheral |

### **Outputs**

| Signal     | Width | Description |
|-----------|-------|-------------|
| `psel`    | 1     | APB peripheral select |
| `penable` | 1     | APB enable signal |
| `pwrite`  | 1     | APB write indicator |
| `paddr`   | 32    | APB address bus |
| `pwdata`  | 32    | APB write data bus |
| `hready`  | 1     | Indicates AHB master can continue |
| `hresp`   | 1     | HREADY response (OKAY / ERROR) |
| `hrdata`  | 32    | Read data from APB peripheral |

---

## FSM Description

The bridge operates as a **finite state machine (FSM)** with the following states:

| State         | Description |
|---------------|-------------|
| `IDLE`        | Waits for a valid AHB transfer |
| `READ_SETUP`  | APB setup phase for read |
| `READ_ENABLE` | APB enable phase, reads data from peripheral |
| `WRITE_WAIT`  | Buffers AHB write address/data for setup |
| `WRITE_SETUP` | APB setup phase for write |
| `WRITE_ENABLE`| APB enable phase, writes data to peripheral |
| `WRITE_PIPE`  | Enables current write while immediately starting next write setup |

**Pipeline Support:** Consecutive writes can be pipelined using `WRITE_PIPE` state, improving bus throughput without waiting for the previous write to complete.

---

## Testbench (`bridge_tb.v`)

The testbench verifies the functionality of `bridge_rtl` including:

- **Single Read Test:** Validates that data from the APB peripheral is correctly latched into AHB read data.
- **Single Write Test:** Ensures write data and address are correctly transmitted to APB.
- **Pipelined Writes:** Simulates multiple consecutive writes to test pipeline behavior.
- **Pipelined Reads:** Simulates consecutive read operations and verifies returned data.

  ---
  **Simulations**

  ![IMAGE]()

**Features:**

- 100 MHz clock generation
- Reset sequence
- Automatic cycle counting
- Console logging of AHB and APB signals for monitoring
- Summary report with pass/fail results

---

**Notes**

- The design is synthesizable for FPGA and ASIC targets.
- Currently, hresp is fixed as OKAY. Error handling can be added based on peripheral response.
- Testbench uses blocking writes of prdata for reads; for more realistic peripheral modeling, a separate APB slave module can be instantiated.

---
License

This project is released under MIT License.
