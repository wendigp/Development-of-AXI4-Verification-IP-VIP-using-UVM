`timescale 1ns/1ps

//==============================================================================//
// TOP LEVEL TESTBENCH - VIP DEVELOPMENT MODE
//==============================================================================//

`include "uvm_macros.svh"
import uvm_pkg::*;
import axi_pkg::*;

module top;

    //-------------------------------------------------------------------------
    // 1. Clock and Reset
    //-------------------------------------------------------------------------
    bit clock;
   // bit rst_n;

    initial begin
        clock = 0;
        forever #5ns clock = ~clock;
    end

 

    //-------------------------------------------------------------------------
    // 2. AXI Interface
    //-------------------------------------------------------------------------
    axi_if pif (clock);

    initial begin
        pif.ARESETn = 0;
        #25ns;
        pif.ARESETn = 1;
    end

    //-------------------------------------------------------------------------
    // 3. UVM Configuration + Test Start
    //-------------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual axi_if)::set(null, "*", "vif", pif);
        run_test();   // or run_test("base_test");
    end

    //-------------------------------------------------------------------------
    // 4. Waveform Dump (Questa-friendly)
    //-------------------------------------------------------------------------
    initial begin
        $wlfdumpvars(0, top);
    end

endmodule
