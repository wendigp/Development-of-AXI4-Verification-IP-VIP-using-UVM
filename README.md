# Development-of-AXI4-Verification-IP-VIP-using-UVM

## Overview
This project implements a reusable AXI4 Verification IP (VIP) developed using SystemVerilog and UVM.  
The VIP is intended to verify AXI4-compliant designs by generating protocol-accurate stimulus, monitoring responses, and checking data integrity, ordering, and protocol compliance.

The verification environment supports independent read and write channel handshaking and is suitable for SoC interconnect and memory-mapped interface verification.

---

## Key Features
- UVM-based AXI4 VIP supporting Master and Slave agents
- Complete implementation of AXI4 channels: AW, W, B, AR, R
- Protocol-accurate valid–ready handshake behavior
- Reusable Monitor and Scoreboard for data integrity and ordering checks
- SystemVerilog Assertions (SVA) for AXI timing and protocol compliance
- Constrained-random stimulus for burst lengths, data widths, and transaction IDs
- Functional coverage to track verification completeness

---

## Verification Architecture
The VIP follows a standard UVM architecture consisting of:
- AXI Interface
- Sequencer
- Driver
- Monitor
- Agent (configurable as Master or Slave)
- Scoreboard
- Environment
- Test

Assertions and functional coverage are integrated to ensure robust protocol validation.

---

## Verification Scope
The VIP verifies:
- AXI read and write transactions
- Independent read/write channel operation
- Burst types and burst lengths
- Address alignment and data integrity
- Out-of-order transaction completion
- AXI timing and valid–ready handshake rules
- Protocol corner cases using constrained-random testing

---

## Tools and Technologies
- Language: SystemVerilog
- Methodology: UVM
- Assertions: SystemVerilog Assertions (SVA)
- Simulators: QuestaSim, Synopsys VCS

---

## Results
- Achieved over 90% functional coverage using constrained-random testing
- Detected protocol violations using assertion-based checks
- Verified correctness across multiple AXI transaction scenarios

---

## Directory Structure
