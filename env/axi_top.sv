//==============================================================================//
// TOP LEVEL TESTBENCH - VIP DEVELOPMENT MODE
// Implementation: 
//   - Pure UVM environment (No RTL/DUT)
//   - Focus: VIP Handshake, Protocol, and Coverage validation
//==============================================================================//

`include "uvm_macros.svh"
import uvm_pkg::*;

module top;

    //-------------------------------------------------------------------------
    // 1. Clock and Reset Signals
    //-------------------------------------------------------------------------
    bit clock;
    bit reset_n;

    initial begin
        clock = 0;
        forever #5ns clock = ~clock;
    end

    initial begin
        reset_n = 0;
        #25ns;
        reset_n = 1;
    end

    //-------------------------------------------------------------------------
    // 2. Interface Instantiation
    // This interface acts as the "Bus" where the VIP components meet.
    //-------------------------------------------------------------------------
    axi_if pif (clock, reset_n);

    //-------------------------------------------------------------------------
    // 3. DUT Instantiation (REMOVED)
    // For VIP Development, the Master and Slave Agents act as each other's DUT.
    //-------------------------------------------------------------------------

    //-------------------------------------------------------------------------
    // 4. Test Entry Point & Config DB Setup
    //-------------------------------------------------------------------------
    initial begin
        // Pass the physical interface to the UVM database
        uvm_config_db #(virtual axi_if)::set(null, "*", "vif", pif);
        
        // Start the UVM test (e.g., +UVM_TESTNAME=incr_burst_test)
        run_test();
    end

    //-------------------------------------------------------------------------
    // 5. Simulation Control
    //-------------------------------------------------------------------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, top);
    end

endmodule