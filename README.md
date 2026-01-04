# Development-of-AXI4-Verification-IP-VIP-using-UVM

## Overview
This project presents a reusable and configurable AXI4 Verification IP (VIP) developed using SystemVerilog and UVM. The VIP is designed to verify AXI4-compliant designs by generating protocol-accurate stimulus, monitoring DUT responses, and validating data integrity, ordering, and protocol compliance.

The verification environment supports independent read and write channel operation, making it suitable for SoC interconnects, memory controllers, and AXI-based peripherals.

---

## Key Features
- UVM-based AXI4 Verification IP with configurable Master and Slave agents
- Complete support for all AXI4 channels: AW, W, B, AR, R
- Protocol-accurate valid–ready handshake implementation
- Reusable Monitor and Scoreboard for data integrity and transaction ordering
- SystemVerilog Assertions (SVA) for AXI timing and protocol compliance checks
- Constrained-random stimulus for burst lengths, data widths, addresses, and transaction IDs
- Functional coverage to measure verification completeness across AXI scenarios
- Automated regression execution using Python scripts and Makefile-driven simulation flow

---

## Verification Architecture
The VIP follows a standard layered UVM architecture, enabling scalability and reuse:

- AXI Interface
- Sequencer
- Driver
- Monitor
- Agent (configurable as Master or Slave)
- Scoreboard
- Environment
- Test

Assertion-based checks and functional coverage are tightly integrated to ensure robust and protocol-compliant verification.

---

## Verification Scope
The verification environment validates:
- AXI4 read and write transactions
- Independent read and write channel handshaking
- Burst types and burst lengths
- Address alignment and data integrity
- Out-of-order transaction completion
- AXI timing rules and valid–ready protocol behavior
- Protocol corner cases using constrained-random testing

---

## Tools and Technologies
- Language: SystemVerilog  
- Methodology: UVM  
- Assertions: SystemVerilog Assertions (SVA)  
- Simulators: QuestaSim, Synopsys VCS  
- Scripting: Python (regression automation and log parsing)  
- Build & Run Flow: Makefile-based simulation control  

---

## Results
- Achieved over 90% functional coverage using constrained-random stimulus
- Detected AXI protocol violations through assertion-based verification
- Verified correct behavior across multiple AXI transaction scenarios, including corner cases
- Successful multi-test regression runs using automated Python and Makefile flow

---

## Directory Structure
```text
Development-of-AXI4-Verification-IP-VIP-using-UVM/
├── agent/
│   ├── axi_driver.sv
│   ├── axi_monitor.sv
│   ├── axi_sequencer.sv
│   └── axi_agent.sv
├── env/
│   ├── axi_scoreboard.sv
│   └── axi_env.sv
├── seq/
│   ├── axi_base_seq.sv
│   └── axi_rw_seq.sv
├── test/
│   └── axi_base_test.sv
├── tb/
│   └── axi_tb_top.sv
├── scripts/
│   └── regression.py
├── Makefile
└── README.md
