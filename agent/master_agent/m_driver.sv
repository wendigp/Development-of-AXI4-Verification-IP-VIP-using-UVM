//===============================================================//
// MASTER DRIVER 
//==============================================================//

import uvm_pkg::*;
`include "uvm_macros.svh"
import axi_defs::*;

class m_driver extends uvm_driver #(axi_txn);

    `uvm_component_utils(m_driver)

    m_config            m_cfg;
    virtual axi_if      vif;

    extern function new(string name = "m_driver", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);
    extern task run_phase(uvm_phase phase);
    extern task send_to_dut(axi_txn xtn);

    // TASK FOR WRITE OPERATION
    extern task write_addr(axi_txn xtn);
    extern task write_data(axi_txn xtn);
    extern task write_response(axi_txn xtn);
    
    // TASK FOR READ OPERATION
    extern task read_addr(axi_txn xtn);
    extern task read_data(axi_txn xtn);
endclass

// CONSTRUCTOR
function m_driver::new(string name = "m_driver", uvm_component parent);
    super.new(name, parent);
endfunction

// BUILD PHASE - Getting configuration
function void m_driver::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(m_config)::get(this, "", "m_config", m_cfg))
        `uvm_fatal("MASTER DRIVER", "CANNOT GET DATA FROM M_CFG. HAVE YOU SET IT?")
endfunction

// CONNECT PHASE
function void m_driver::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vif = m_cfg.vif;
    if(vif == null)
        `uvm_fatal("MASTER DRIVER", "VIF IS NULL")
endfunction

// RUN PHASE - Driving 
task m_driver::run_phase(uvm_phase phase);
    // Wait for reset
    wait(vif.ARESETn === 1);
    
    // Initialize Ready signals to 0 (AXI Reset/Default state)
    vif.drv_cb_m.RREADY <= 0;
    vif.drv_cb_m.BREADY <= 0;

    forever begin
        seq_item_port.get_next_item(req);
        `uvm_info("MASTER DRIVER", $sformatf("RECEIVED TRANSACTION: is_write=%0d", req.is_write), UVM_MEDIUM)
        send_to_dut(req);
        seq_item_port.item_done();
    end
endtask

//================================================================//
// SEND TO DUT
//===============================================================//
task m_driver::send_to_dut(axi_txn xtn);
   
    if(xtn.is_write == 1) begin
        `uvm_info(get_type_name(), "WRITE TRANSACTION STARTS", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("WDATA.size=%0d, AWLEN=%0d", xtn.WDATA.size(), xtn.AWLEN), UVM_HIGH)
        fork
            write_addr(xtn);
            write_data(xtn);
        join
        write_response(xtn);
        `uvm_info(get_type_name(), "WRITE TRANSACTION ENDS", UVM_MEDIUM)
    end
    // READ TRANSACTION
    else begin
        `uvm_info(get_type_name(), "READ TRANSACTION STARTS", UVM_MEDIUM)
        read_addr(xtn);
        read_data(xtn);
        `uvm_info(get_type_name(), "READ TRANSACTION ENDS", UVM_MEDIUM)
    end
endtask

//***************************************************************************//
// WRITE ADDRESS CHANNEL
//**************************************************************************//
task m_driver::write_addr(axi_txn xtn);
    `uvm_info(get_type_name(), "START OF WRITE ADDRESS CHANNEL", UVM_HIGH)

    @(vif.drv_cb_m);
    vif.drv_cb_m.AWADDR  <= xtn.AWADDR;
    vif.drv_cb_m.AWID    <= xtn.AWID;
    vif.drv_cb_m.AWSIZE  <= xtn.AWSIZE;
    vif.drv_cb_m.AWBURST <= xtn.AWBURST;
    vif.drv_cb_m.AWLEN   <= xtn.AWLEN;
    vif.drv_cb_m.AWVALID <= 1'b1;

    // Wait for READY
    do begin
        @(vif.drv_cb_m);
    end while(vif.drv_cb_m.AWREADY !== 1'b1);

    vif.drv_cb_m.AWVALID <= 1'b0;
    vif.drv_cb_m.AWADDR  <= 'bx;
    vif.drv_cb_m.AWID    <= 'bx;

    repeat($urandom_range(1,5)) @(vif.drv_cb_m);
    `uvm_info(get_type_name(), "END OF WRITE ADDRESS CHANNEL", UVM_HIGH)
endtask

//***********************************************************************************//
// WRITE DATA CHANNEL
//**********************************************************************************//
task m_driver::write_data(axi_txn xtn);
    `uvm_info(get_type_name(), "START OF WRITE DATA CHANNEL", UVM_HIGH)

    for(int i = 0; i <= xtn.AWLEN; i++) begin
        @(vif.drv_cb_m);
        vif.drv_cb_m.WVALID      <= 1'b1;
        vif.drv_cb_m.WDATA       <= xtn.WDATA[i];
        vif.drv_cb_m.WSTRB       <= xtn.WSTRB[i];
        vif.drv_cb_m.WLAST       <= (i == xtn.AWLEN);

        `uvm_info(get_type_name(), $sformatf("Beat %0d: WDATA=0x%0h, WSTRB=0x%0h", i, xtn.WDATA[i], xtn.WSTRB[i]), UVM_HIGH)

        //Wait for Slave READY
        do begin
            @(vif.drv_cb_m);
        end while(vif.drv_cb_m.WREADY !== 1'b1);
        
        vif.drv_cb_m.WVALID      <= 1'b0;
        vif.drv_cb_m.WLAST       <= 1'b0;
        vif.drv_cb_m.WDATA       <= 'bx;

        repeat($urandom_range(1,5)) @(vif.drv_cb_m);
    end
    `uvm_info(get_type_name(), "END OF WRITE DATA CHANNEL", UVM_HIGH)
endtask

//****************************************************************************************//
// WRITE RESPONSE CHANNEL
//***************************************************************************************//
task m_driver::write_response(axi_txn xtn);
    `uvm_info(get_type_name(), "START OF WRITE RESPONSE CHANNEL", UVM_HIGH)

    do begin 
        @(vif.drv_cb_m);
    end while(vif.drv_cb_m.BVALID !== 1'b1);

    // Master may wait before asserting BREADY
    repeat($urandom_range(0,5)) @(vif.drv_cb_m);
    vif.drv_cb_m.BREADY      <= 1'b1;
    @(vif.drv_cb_m);
    vif.drv_cb_m.BREADY      <= 1'b0;

    `uvm_info(get_type_name(), "END OF WRITE RESPONSE CHANNEL", UVM_HIGH)
endtask

//********************************************************************************************//
// READ ADDRESS CHANNEL
//*******************************************************************************************//
task m_driver::read_addr(axi_txn xtn);
    `uvm_info(get_type_name(), "START OF READ ADDRESS CHANNEL", UVM_HIGH)

    @(vif.drv_cb_m);
    vif.drv_cb_m.ARVALID        <= 1'b1;
    vif.drv_cb_m.ARADDR         <= xtn.ARADDR;
    vif.drv_cb_m.ARID           <= xtn.ARID;
    vif.drv_cb_m.ARLEN          <= xtn.ARLEN;
    vif.drv_cb_m.ARSIZE         <= xtn.ARSIZE;
    vif.drv_cb_m.ARBURST        <= xtn.ARBURST;

    do begin 
        @(vif.drv_cb_m);
    end while(vif.drv_cb_m.ARREADY !== 1'b1);
    
    vif.drv_cb_m.ARVALID        <= 1'b0;
    vif.drv_cb_m.ARADDR         <= 'bx;

    repeat($urandom_range(1,5)) @(vif.drv_cb_m);
    `uvm_info(get_type_name(), "END OF READ ADDRESS CHANNEL", UVM_LOW)
endtask

//******************************************************************************************//
// READ DATA CHANNEL
//*****************************************************************************************//
task m_driver::read_data(axi_txn xtn);
  int i = 0;
  `uvm_info(get_type_name(), "START OF READ DATA", UVM_HIGH)

  while (i <= xtn.ARLEN) begin
    // Master decides when to be ready 
    vif.drv_cb_m.RREADY <= 1'b1;

    // Sample at every clock edge
    @(vif.drv_cb_m);

    // THE HANDSHAKE CHECK
    if (vif.drv_cb_m.RVALID === 1'b1 && vif.drv_cb_m.RREADY === 1'b1) begin
      
      // Perform Protocol Checks on the sampled handshake
      if (i == xtn.ARLEN && vif.drv_cb_m.RLAST !== 1'b1)
        `uvm_error("AXI_LAST", "RLAST missing on last beat!")
      
      if (i != xtn.ARLEN && vif.drv_cb_m.RLAST === 1'b1)
        `uvm_error("AXI_LAST", "RLAST asserted early!")

      `uvm_info(get_type_name(), $sformatf("Beat %0d ACKED: RDATA=0x%0h", i, vif.drv_cb_m.RDATA), UVM_HIGH)
      
      // Increment beat counter only on successful handshake
      i++;

      //  Master can pull down RREADY to create backpressure
      vif.drv_cb_m.RREADY <= 1'b0;
      repeat($urandom_range(0,2)) @(vif.drv_cb_m);
    end
    else begin
      // If no handshake, we just loop back and keep RREADY high 
      // until the Slave provides RVALID
    end
  end

  `uvm_info(get_type_name(), "END OF READ DATA", UVM_HIGH)
endtask



/*
Master delay improves realism, exposes corner cases,
 validates AXI backpressure handling, and strengthens coverage and confidence in the design.

 Here are the primary advantages:

1. Verifies Handshake Robustness: By delaying VALID (or READY for read channels), 
you force the Slave to maintain its state and signal stability 
(e.g., ensuring READY doesn't toggle illegally while waiting for VALID).

2. Stresses Backpressure Logic: It simulates a "busy" master. 
This verifies if the Slave can handle gaps in data bursts 
without losing information or corrupting the internal address increment logic.

3. Exposes Synchronization Issues: Random delays help identify bugs where the Slave might incorrectly
 assume that data beats will always arrive on consecutive clock cycles.

4. Tests FIFO Thresholds: Inserting delays allows the Slave's internal buffers to fill or empty at different rates,
 stressing "Almost Full" or "Almost Empty" conditions that wouldn't be reached in a zero-delay simulation.

5. Increases Functional Coverage: It explores a wider range of timing scenarios within the AXI4 specification, 
ensuring the design is verified across its full timing envelope rather than just the "best-case" scenario.

6. Validates Protocol Transitions: It ensures that signals like WLAST or RLAST are sampled correctly only when the handshake occurs,
 even if there is a long stall before the final beat.
*/