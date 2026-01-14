//==============================================================================//
// AXI SLAVE DRIVER (FIXED - RLAST Issue Resolved)
//==============================================================================//

import uvm_pkg::*;
`include "uvm_macros.svh"

class s_driver extends uvm_driver #(axi_txn);

  `uvm_component_utils(s_driver)

  s_config        s_cfg;
  virtual axi_if  vif;

  // Byte-addressable associative memory
  bit [7:0] slave_mem [bit [31:0]];

  function new(string name="s_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(s_config)::get(this,"","s_config",s_cfg))
      `uvm_fatal("SLAVE_DRIVER","Cannot get s_config from config_db")
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vif = s_cfg.vif;
    if (vif == null)
      `uvm_fatal("SLAVE_DRIVER","VIF is NULL")
  endfunction

  //--------------------------------------------------------------------------
  // MAIN RUN PHASE
  //--------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    reset_signals();

    forever begin
      wait(vif.ARESETn === 1'b1);

      fork
        handle_write();
        handle_read();
      join_none

      wait(vif.ARESETn === 1'b0);
      disable fork;
      reset_signals();
    end
  endtask

  //--------------------------------------------------------------------------
  // RESET TASK
  //--------------------------------------------------------------------------
  task reset_signals();
    vif.drv_cb_s.AWREADY <= 1'b0;
    vif.drv_cb_s.WREADY  <= 1'b0;
    vif.drv_cb_s.BVALID  <= 1'b0;
    vif.drv_cb_s.ARREADY <= 1'b0;
    vif.drv_cb_s.RVALID  <= 1'b0;
    vif.drv_cb_s.RLAST   <= 1'b0;
    vif.drv_cb_s.BID     <= '0;
    vif.drv_cb_s.RID     <= '0;
    vif.drv_cb_s.BRESP   <= '0;
    vif.drv_cb_s.RRESP   <= '0;
    vif.drv_cb_s.RDATA   <= '0;
  endtask

  //--------------------------------------------------------------------------
  // WRITE CHANNEL
  //--------------------------------------------------------------------------
  task handle_write();
    axi_txn xtn;
    forever begin
      xtn = axi_txn::type_id::create("xtn");
      write_addr_phase(xtn);
      write_data_phase(xtn);
      write_resp_phase(xtn);
    end
  endtask

  task write_addr_phase(axi_txn xtn);
    vif.drv_cb_s.AWREADY <= 1'b1;

    // Wait for AWVALID handshake
    do begin
      @(vif.drv_cb_s);
    end while (vif.drv_cb_s.AWVALID !== 1'b1);

    xtn.AWID    = vif.drv_cb_s.AWID;
    xtn.AWADDR  = vif.drv_cb_s.AWADDR;
    xtn.AWLEN   = vif.drv_cb_s.AWLEN;
    xtn.AWSIZE  = vif.drv_cb_s.AWSIZE;
    xtn.AWBURST = vif.drv_cb_s.AWBURST;

    vif.drv_cb_s.AWREADY <= 1'b0;
  endtask

  task write_data_phase(axi_txn xtn);
    bit [31:0] addr = xtn.AWADDR;
    int beat_bytes  = (1 << xtn.AWSIZE);

    for (int k = 0; k <= xtn.AWLEN; k++) begin
      vif.drv_cb_s.WREADY <= 1'b1;

      // Wait for WVALID handshake
      do begin
        @(vif.drv_cb_s);
      end while (vif.drv_cb_s.WVALID !== 1'b1);

      // Perform memory update based on WSTRB
      for (int i = 0; i < 4; i++) begin
        if (vif.drv_cb_s.WSTRB[i])
          slave_mem[addr+i] = vif.drv_cb_s.WDATA[i*8 +: 8];
      end

      // Address increment for INCR burst
      if (xtn.AWBURST == 2'b01)
        addr += beat_bytes;

      // Stop early if WLAST is asserted (protocol safe)
      if (vif.drv_cb_s.WLAST)
        break;
    end

    vif.drv_cb_s.WREADY <= 1'b0;
  endtask

  task write_resp_phase(axi_txn xtn);
    @(vif.drv_cb_s);

    vif.drv_cb_s.BID    <= xtn.AWID;
    vif.drv_cb_s.BRESP  <= 2'b00; // OKAY
    vif.drv_cb_s.BVALID <= 1'b1;

    // Wait for BREADY handshake
    do begin
      @(vif.drv_cb_s);
    end while (vif.drv_cb_s.BREADY !== 1'b1);

    vif.drv_cb_s.BVALID <= 1'b0;
  endtask

  //--------------------------------------------------------------------------
  // READ CHANNEL
  //--------------------------------------------------------------------------
  task handle_read();
    axi_txn xtn;
    forever begin
      xtn = axi_txn::type_id::create("xtn");
      read_addr_phase(xtn);
      read_data_phase(xtn);
    end
  endtask

  task read_addr_phase(axi_txn xtn);
    vif.drv_cb_s.ARREADY <= 1'b1;

    // Wait for ARVALID handshake
    do begin
      @(vif.drv_cb_s);
    end while (vif.drv_cb_s.ARVALID !== 1'b1);

    xtn.ARID    = vif.drv_cb_s.ARID;
    xtn.ARADDR  = vif.drv_cb_s.ARADDR;
    xtn.ARLEN   = vif.drv_cb_s.ARLEN;
    xtn.ARSIZE  = vif.drv_cb_s.ARSIZE;
    xtn.ARBURST = vif.drv_cb_s.ARBURST;

    vif.drv_cb_s.ARREADY <= 1'b0;
  endtask

  //--------------------------------------------------------------------------
  // READ DATA PHASE (FIXED RLAST + RVALID ALIGNMENT)
  //--------------------------------------------------------------------------
  task read_data_phase(axi_txn xtn);
  bit [31:0] addr = xtn.ARADDR;
  int beat_bytes  = (1 << xtn.ARSIZE);
  bit [31:0] rdata_temp;

  for (int beat = 0; beat <= xtn.ARLEN; beat++) begin

    // 1) Prepare Read Data
    rdata_temp = '0;
    for (int b = 0; b < 4; b++) begin
      rdata_temp[b*8 +: 8] = slave_mem.exists(addr+b) ? slave_mem[addr+b] : 8'h00;
    end

    // 2) Drive everything together (VALID + DATA + LAST must be stable)
    vif.drv_cb_s.RID    <= xtn.ARID;
    vif.drv_cb_s.RDATA  <= rdata_temp;
    vif.drv_cb_s.RRESP  <= 2'b00;
    vif.drv_cb_s.RLAST  <= (beat == xtn.ARLEN);
    vif.drv_cb_s.RVALID <= 1'b1;

    // 3) Wait until handshake happens (slave must HOLD signals)
    do begin
      @(vif.drv_cb_s);
    end while (!(vif.drv_cb_s.RREADY === 1'b1 && vif.drv_cb_s.RVALID === 1'b1));

    // 4) Drop valid after handshake
    vif.drv_cb_s.RVALID <= 1'b0;
    vif.drv_cb_s.RLAST  <= 1'b0;

    // 5) Increment addr for INCR burst
    if (xtn.ARBURST == 2'b01)
      addr += beat_bytes;
  end
endtask


endclass
