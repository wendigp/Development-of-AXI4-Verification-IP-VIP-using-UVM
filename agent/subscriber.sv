//==============================================================================//
// AXI FUNCTIONAL COVERAGE SUBSCRIBER (FIXED)
//==============================================================================//
class axi_subscriber extends uvm_subscriber #(axi_txn);

  `uvm_component_utils(axi_subscriber)

  axi_txn xtn;

  // RAW tracking
  bit [31:0] last_write_start_addr;
  bit [31:0] last_write_end_addr;
  bit [1:0]  last_write_burst;
  bit        write_seen;
  bit        raw_hit;

  // WSTRB
  bit [3:0] current_wstrb;

  virtual axi_if vif;

  //==============================================================================
  // WRITE COVERAGE
  //==============================================================================
  covergroup write_cg;
    option.per_instance = 1;

    W_ADDR: coverpoint xtn.AWADDR {
      bins zero_addr  = {32'h0};
      bins low_range  = {[32'h1 : 32'h0000_0FFF]};
      bins normal     = {[32'h0000_1000 : 32'h7FFF_FFFF]};
      bins io_range   = {[32'h8000_0000 : 32'hEFFF_FFFF]};
      bins high_addr  = {[32'hF000_0000 : 32'hFFFF_FFFF]};
    }

    W_LEN: coverpoint xtn.AWLEN {
      bins single = {0};
      bins pow2   = {1,3,7,15};
      bins large_burst = {[16:254]};
      bins max    = {255};
    }

    W_SIZE: coverpoint xtn.AWSIZE {
      bins b1 = {3'b000};
      bins b2 = {3'b001};
      bins b4 = {3'b010};
    }

    W_BURST: coverpoint xtn.AWBURST {
      bins fixed = {2'b00};
      bins incr  = {2'b01};
      bins wrap  = {2'b10};
      illegal_bins res = {2'b11};
    }

    W_BURST_X_LEN : cross W_BURST, W_LEN;
    W_SIZE_X_LEN  : cross W_SIZE,  W_LEN;
  endgroup

  //==============================================================================
  // READ COVERAGE
  //==============================================================================
  covergroup read_cg;
    option.per_instance = 1;

    R_ADDR: coverpoint xtn.ARADDR {
      bins zero_addr  = {32'h0};
      bins low_range  = {[32'h1 : 32'h0000_0FFF]};
      bins normal     = {[32'h0000_1000 : 32'h7FFF_FFFF]};
      bins io_range   = {[32'h8000_0000 : 32'hEFFF_FFFF]};
      bins high_addr  = {[32'hF000_0000 : 32'hFFFF_FFFF]};
    }

    R_LEN: coverpoint xtn.ARLEN {
      bins single = {0};
      bins pow2   = {1,3,7,15};
      bins large_burst = {[16:254]};
      bins max    = {255};
    }

    R_SIZE: coverpoint xtn.ARSIZE {
      bins b1 = {3'b000};
      bins b2 = {3'b001};
      bins b4 = {3'b010};
    }

    R_BURST: coverpoint xtn.ARBURST {
      bins fixed = {2'b00};
      bins incr  = {2'b01};
      bins wrap  = {2'b10};
      illegal_bins res = {2'b11};
    }

    R_BURST_X_LEN : cross R_BURST, R_LEN;
    R_SIZE_X_LEN  : cross R_SIZE,  R_LEN;
  endgroup

  //==============================================================================
  // WSTRB COVERAGE
  //==============================================================================
  covergroup wstrb_cg;
    option.per_instance = 1;

    STRB: coverpoint current_wstrb {
      bins full_word = {4'b1111};
      bins single    = {4'b0001,4'b0010,4'b0100,4'b1000};
      bins half      = {4'b0011,4'b1100};
      bins sparse    = {4'b0101,4'b1010};
      bins none      = {4'b0000};
    }
  endgroup

  //==============================================================================
  // SYSTEM COVERAGE (RAW)
  //==============================================================================
  covergroup system_cg;
    option.per_instance = 1;

    RAW_DETECT : coverpoint raw_hit {
      bins detected = {1};
    }

    TRANS_TYPE : coverpoint xtn.is_write {
      bins write = {1};
      bins read  = {0};
    }
  endgroup

  //==============================================================================
  // Constructor
  //==============================================================================
  function new(string name="axi_subscriber", uvm_component parent);
    super.new(name,parent);
    write_cg  = new();
    read_cg   = new();
    wstrb_cg  = new();
    system_cg = new();
    write_seen = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual axi_if)::get(this,"","vif",vif))
      `uvm_warning("COV","VIF not found – reset gating disabled")
  endfunction

  //==============================================================================
  // Sampling
  //==============================================================================
  function void write(axi_txn t);
    xtn = t;

    if (vif != null && vif.ARESETn !== 1'b1) begin
      write_seen = 0;
      return;
    end

    if (xtn.is_write) begin
      write_cg.sample();

      last_write_start_addr = xtn.AWADDR;
      last_write_end_addr =
        xtn.AWADDR + ((1 << xtn.AWSIZE) * (xtn.AWLEN + 1)) - 1;
      last_write_burst = xtn.AWBURST;
      write_seen = 1;

      // FIX: Sample only first beat's WSTRB
      if (xtn.WSTRB.size() > 0) begin
        current_wstrb = xtn.WSTRB[0];
        wstrb_cg.sample();
      end
    end

    if (!xtn.is_write) begin
      read_cg.sample();

      raw_hit = write_seen &&
                (last_write_burst != 2'b00) &&
                (xtn.ARADDR >= last_write_start_addr) &&
                (xtn.ARADDR <= last_write_end_addr);

      system_cg.sample();
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV",
      $sformatf(
        "WRITE=%0.2f%% READ=%0.2f%% WSTRB=%0.2f%% SYSTEM=%0.2f%%",
        write_cg.get_inst_coverage(),
        read_cg.get_inst_coverage(),
        wstrb_cg.get_inst_coverage(),
        system_cg.get_inst_coverage()),
      UVM_LOW)
  endfunction

endclass