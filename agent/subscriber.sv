//==============================================================================//
// AXI FUNCTIONAL COVERAGE SUBSCRIBER
// Implementation: Captures and tracks protocol and data coverage
// Fixes: 
//  - Added large_burst bin to R_LEN for symmetry and closure
//  - Maintained 32-bit size limits (max 4 bytes) based on driver implementation
//=============================================================================//
class axi_subscriber extends uvm_subscriber #(axi_txn);

    `uvm_component_utils(axi_subscriber)

    axi_txn xtn;
    
    // Tracking for RAW coverage
    bit [31:0] last_write_start_addr;
    bit [31:0] last_write_end_addr;
    bit [1:0]  last_write_burst;
    bit        write_seen;

    // Local variable for strobe sampling loop
    bit [3:0] current_wstrb;

    // Virtual interface for coverage gating
    virtual axi_if vif;

    //==============================================================================//
    // WRITE COVERGROUP
    //==============================================================================//
    covergroup write_cg;
        option.per_instance = 1;
        option.name = "axi_write_coverage";
        option.goal = 100;

        W_ADDR: coverpoint xtn.AWADDR {
            bins zero_addr    = {32'h0000_0000};
            bins low_range    = {[32'h0000_0001 : 32'h0000_0FFF]}; 
            bins stack_heap   = {[32'h0000_1000 : 32'h7FFF_FFFF]};
            bins io_range     = {[32'h8000_0000 : 32'hEFFF_FFFF]};
            bins high_addr    = {[32'hF000_0000 : 32'hFFFF_FFFF]};
        }

        W_LEN: coverpoint xtn.AWLEN {
            bins single_beat  = {0};
            bins small_pow2   = {1, 3, 7, 15}; 
            bins large_burst  = {[16:254]};
            bins max_axi4     = {255};
        }

        W_SIZE: coverpoint xtn.AWSIZE {
            bins byte_1    = {3'b000};
            bins byte_2    = {3'b001};
            bins byte_4    = {3'b010};
        }

        W_BURST_TYPE: coverpoint xtn.AWBURST {
            bins fixed        = {2'b00};
            bins incr         = {2'b01};
            bins wrap         = {2'b10};
            illegal_bins res  = {2'b11};
        }

        W_BURST_X_LEN:  cross W_BURST_TYPE, W_LEN;
        W_SIZE_X_LEN:   cross W_SIZE, W_LEN;
    endgroup

    //==============================================================================//
    // READ COVERGROUP
    //==============================================================================//
    covergroup read_cg;
        option.per_instance = 1;
        option.name = "axi_read_coverage";
        option.goal = 100;

        R_ADDR: coverpoint xtn.ARADDR {
            bins zero_addr    = {32'h0000_0000};
            bins low_range    = {[32'h0000_0001 : 32'h0000_0FFF]};
            bins stack_heap   = {[32'h0000_1000 : 32'h7FFF_FFFF]};
            bins io_range     = {[32'h8000_0000 : 32'hEFFF_FFFF]};
            bins high_addr    = {[32'hF000_0000 : 32'hFFFF_FFFF]};
        }

        R_LEN: coverpoint xtn.ARLEN {
            bins single_beat  = {0};
            bins small_pow2   = {1, 3, 7, 15};
            bins large_burst  = {[16:254]}; // UPDATED: Added for symmetry
            bins max_axi4     = {255};
        }

        R_SIZE: coverpoint xtn.ARSIZE {
            bins byte_1    = {3'b000};
            bins byte_2    = {3'b001};
            bins byte_4    = {3'b010};
        }

        R_BURST_TYPE: coverpoint xtn.ARBURST {
            bins fixed        = {2'b00};
            bins incr         = {2'b01};
            bins wrap         = {2'b10};
            illegal_bins res  = {2'b11};
        }

        R_BURST_X_LEN: cross R_BURST_TYPE, R_LEN;
        R_SIZE_X_LEN:  cross R_SIZE, R_LEN;
    endgroup

    //==============================================================================//
    // WSTRB COVERGROUP
    //==============================================================================//
    covergroup wstrb_cg;
        option.per_instance = 1;
        option.name = "axi_wstrb_coverage";
        option.goal = 100;

        STRB: coverpoint current_wstrb {
            bins full_word    = {4'b1111};
            bins partial_byte = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
            bins partial_half = {4'b0011, 4'b1100};
            bins sparse       = {4'b1010, 4'b0101, 4'b1001};
            bins no_strobe    = {4'b0000};
        }

        STRB_X_ADDR_ALIGN: cross STRB, xtn.AWADDR[1:0] {
            ignore_bins no_strb = binsof(STRB.no_strobe);
        }
    endgroup

    //==============================================================================//
    // SYSTEM LEVEL COVERGROUP (RAW & RESET)
    //==============================================================================//
    covergroup system_cg;
        option.per_instance = 1;
        option.name = "axi_system_coverage";
        option.goal = 100;
        option.weight = 2;

        RAW_ADDR_MATCH: coverpoint (write_seen && (last_write_burst != 2'b00) && 
                                   (xtn.ARADDR inside {[last_write_start_addr : last_write_end_addr]})) {
            bins raw_detected = {1};
        }

        RESET_STATE: coverpoint vif.rst_n {
            bins active = {0};
            bins inactive = {1};
        }

        TRANS_PHASE: coverpoint xtn.is_write {
            bins wr = {1};
            bins rd = {0};
        }

        RESET_X_TRANS: cross RESET_STATE, TRANS_PHASE;
    endgroup

    function new(string name = "axi_subscriber", uvm_component parent);
        super.new(name, parent);
        write_cg = new();
        read_cg = new();
        wstrb_cg = new();
        system_cg = new();
        write_seen = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db #(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_error("COV", "VIF not found for coverage gating")
    endfunction

    virtual function void write(axi_txn t);
        this.xtn = t;
        system_cg.sample();

        if (vif != null && vif.rst_n === 0) begin
            write_seen = 0;
            return;
        end

        if (xtn.is_write && !$isunknown(xtn.AWADDR)) begin
            write_cg.sample();
            last_write_start_addr = xtn.AWADDR;
            last_write_end_addr   = xtn.AWADDR + ((1 << xtn.AWSIZE) * (xtn.AWLEN + 1)) - 1;
            last_write_burst      = xtn.AWBURST;
            write_seen = 1;
            
            foreach (xtn.WSTRB[i]) begin
                this.current_wstrb = xtn.WSTRB[i];
                wstrb_cg.sample();
            end
        end 
        
        if (!xtn.is_write && !$isunknown(xtn.ARADDR)) begin
            read_cg.sample();
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV_REPORT", $sformatf("Write Coverage: %0.2f%%", write_cg.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV_REPORT", $sformatf("Read Coverage: %0.2f%%", read_cg.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV_REPORT", $sformatf("WSTRB Coverage: %0.2f%%", wstrb_cg.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV_REPORT", $sformatf("System Coverage: %0.2f%%", system_cg.get_inst_coverage()), UVM_LOW)
        
        if ($get_coverage() < 100) begin
            `uvm_warning("COV_CLOSURE", "Total functional coverage is below 100% target")
        end
    endfunction

endclass