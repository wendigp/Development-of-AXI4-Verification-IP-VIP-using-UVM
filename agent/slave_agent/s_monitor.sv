//==============================================================================//
// SLAVE MONITOR
// Implementation: Observes AXI4 handshakes on the Slave side of the interface
// Added: Full Reset awareness (Initial and mid-transaction)
//=============================================================================//
class s_monitor extends uvm_monitor;

    `uvm_component_utils(s_monitor)

    s_config                        s_cfg;
    virtual axi_if                  vif;

    uvm_analysis_port #(axi_txn)    analysis_port;

    extern function new(string name = "s_monitor", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);
    extern task run_phase(uvm_phase phase);

    extern task collect_write_data_slave();
    extern task collect_read_data_slave();
endclass

//==============================================================================//
// CONSTRUCTOR
//==============================================================================//
function s_monitor::new(string name = "s_monitor", uvm_component parent);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
endfunction

//==============================================================================//
// BUILD PHASE
//==============================================================================//
function void s_monitor::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(s_config)::get(this, "", "s_config", s_cfg))
        `uvm_fatal("SLAVE_MONITOR", "CANNOT GET s_config")
endfunction

//==============================================================================//
// CONNECT PHASE
//==============================================================================//
function void s_monitor::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vif = s_cfg.vif;
    if(vif == null)
        `uvm_fatal("SLAVE_MONITOR", "VIF IS NULL")
endfunction

//==============================================================================//
// RUN PHASE
//==============================================================================//
task s_monitor::run_phase(uvm_phase phase);
    super.run_phase(phase);
    fork
        collect_write_data_slave();
        collect_read_data_slave();
    join_none
endtask

//==============================================================================//
// WRITE CHANNEL MONITOR
//==============================================================================//
task s_monitor::collect_write_data_slave();
    axi_txn xtn;

    forever begin
        // Wait for Reset Release
        if (!vif.rst_n) begin
            @(posedge vif.rst_n);
        end

        xtn = axi_txn::type_id::create("xtn", this);

        // AW handshake
        do begin 
            @(vif.mon_cb_s);
            if (!vif.rst_n) break; 
        end while(!(vif.mon_cb_s.AWVALID && vif.mon_cb_s.AWREADY));

        if (!vif.rst_n) continue; // Restart on mid-transaction reset

        xtn.AWADDR  = vif.mon_cb_s.AWADDR;
        xtn.AWID    = vif.mon_cb_s.AWID;
        xtn.AWLEN   = vif.mon_cb_s.AWLEN;
        xtn.AWBURST = vif.mon_cb_s.AWBURST;

        // W data beats
        for (int i = 0; i <= xtn.AWLEN; i++) begin
            do begin 
                @(vif.mon_cb_s);
                if (!vif.rst_n) break;
            end while(!(vif.mon_cb_s.WVALID && vif.mon_cb_s.WREADY));

            if (!vif.rst_n) break;

            xtn.WDATA.push_back(vif.mon_cb_s.WDATA);
            xtn.WSTRB.push_back(vif.mon_cb_s.WSTRB);

            if (i != xtn.AWLEN && vif.mon_cb_s.WLAST)
                `uvm_error("SLV_MON_WR", $sformatf("Early WLAST at beat %0d", i))

            if (i == xtn.AWLEN && !vif.mon_cb_s.WLAST)
                `uvm_error("SLV_MON_WR", "Missing WLAST on final beat")
        end

        if (!vif.rst_n) continue;

        // B response
        do begin 
            @(vif.mon_cb_s);
            if (!vif.rst_n) break;
        end while(!(vif.mon_cb_s.BVALID && vif.mon_cb_s.BREADY));

        if (!vif.rst_n) continue;

        xtn.BID   = vif.mon_cb_s.BID;
        xtn.BRESP = vif.mon_cb_s.BRESP;

        analysis_port.write(xtn);
    end
endtask

//==============================================================================//
// READ CHANNEL MONITOR
//==============================================================================//
task s_monitor::collect_read_data_slave();
    axi_txn xtn;

    forever begin
        if (!vif.rst_n) begin
            @(posedge vif.rst_n);
        end

        xtn = axi_txn::type_id::create("xtn", this);

        // AR handshake
        do begin 
            @(vif.mon_cb_s);
            if (!vif.rst_n) break;
        end while(!(vif.mon_cb_s.ARVALID && vif.mon_cb_s.ARREADY));

        if (!vif.rst_n) continue;

        xtn.ARADDR  = vif.mon_cb_s.ARADDR;
        xtn.ARID    = vif.mon_cb_s.ARID;
        xtn.ARLEN   = vif.mon_cb_s.ARLEN;
        xtn.ARBURST = vif.mon_cb_s.ARBURST;

        // R data beats
        for (int i = 0; i <= xtn.ARLEN; i++) begin
            do begin 
                @(vif.mon_cb_s);
                if (!vif.rst_n) break;
            end while(!(vif.mon_cb_s.RVALID && vif.mon_cb_s.RREADY));

            if (!vif.rst_n) break;

            xtn.RDATA.push_back(vif.mon_cb_s.RDATA);
            xtn.RID   = vif.mon_cb_s.RID;
            xtn.RRESP = vif.mon_cb_s.RRESP;

            if (i != xtn.ARLEN && vif.mon_cb_s.RLAST)
                `uvm_error("SLV_MON_RD", $sformatf("Early RLAST at beat %0d", i))

            if (i == xtn.ARLEN && !vif.mon_cb_s.RLAST)
                `uvm_error("SLV_MON_RD", "Missing RLAST on final beat")
        end

        if (!vif.rst_n) continue;

        analysis_port.write(xtn);
    end
endtask