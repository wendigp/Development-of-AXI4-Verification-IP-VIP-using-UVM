//==============================================================================
// AXI SLAVE MONITOR - FINAL (QUEUE CORRECT, RESET SAFE)
// Observes AXI handshakes from the Slave side
//==============================================================================

class s_monitor extends uvm_monitor;

    `uvm_component_utils(s_monitor)

    s_config        s_cfg;
    virtual axi_if  vif;

    uvm_analysis_port #(axi_txn) analysis_port;

    //--------------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------------
    function new(string name = "s_monitor", uvm_component parent);
        super.new(name, parent);
        analysis_port = new("analysis_port", this);
    endfunction

    //--------------------------------------------------------------------------
    // Build
    //--------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(s_config)::get(this, "", "s_config", s_cfg))
            `uvm_fatal("SLAVE_MONITOR", "Cannot get s_config")
    endfunction

    //--------------------------------------------------------------------------
    // Connect
    //--------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        vif = s_cfg.vif;
        if (vif == null)
            `uvm_fatal("SLAVE_MONITOR", "VIF is NULL")
    endfunction

    //--------------------------------------------------------------------------
    // Run
    //--------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        forever begin
            // Wait for reset release
            wait (vif.ARESETn === 1);

            fork : slave_mon_threads
                begin
                    fork
                        collect_write_data_slave();
                        collect_read_data_slave();
                    join
                end
                begin
                    wait (vif.ARESETn === 0);
                end
            join_any

            // Kill all collection threads on reset
            disable slave_mon_threads;
            `uvm_info("SLAVE_MONITOR",
                      "Reset detected: Collection threads terminated safely",
                      UVM_HIGH)
        end
    endtask

    //--------------------------------------------------------------------------
    // WRITE TRANSACTION COLLECTION
    //--------------------------------------------------------------------------
    task collect_write_data_slave();
        forever begin
            axi_txn xtn = axi_txn::type_id::create("xtn", this);

            // ---------------- AW ----------------
            do @(vif.mon_cb_s);
            while (!(vif.mon_cb_s.AWVALID && vif.mon_cb_s.AWREADY));

            xtn.is_write = 1;

            xtn.AWADDR  = vif.mon_cb_s.AWADDR;
            xtn.AWID    = vif.mon_cb_s.AWID;
            xtn.AWLEN   = vif.mon_cb_s.AWLEN;
            xtn.AWSIZE  = vif.mon_cb_s.AWSIZE;
            xtn.AWBURST = vif.mon_cb_s.AWBURST;

            xtn.WDATA.delete();
            xtn.WSTRB.delete();

            // ---------------- W ----------------
            for (int i = 0; i <= xtn.AWLEN; i++) begin
                do @(vif.mon_cb_s);
                while (!(vif.mon_cb_s.WVALID && vif.mon_cb_s.WREADY));

                xtn.WDATA.push_back(vif.mon_cb_s.WDATA);
                xtn.WSTRB.push_back(vif.mon_cb_s.WSTRB);

                if (i != xtn.AWLEN && vif.mon_cb_s.WLAST)
                    `uvm_error("SLV_MON_WR", "WLAST asserted early")

                if (i == xtn.AWLEN && !vif.mon_cb_s.WLAST)
                    `uvm_error("SLV_MON_WR", "WLAST missing on final beat")
            end

            // ---------------- B ----------------
            do @(vif.mon_cb_s);
            while (!(vif.mon_cb_s.BVALID && vif.mon_cb_s.BREADY));

            xtn.BID   = vif.mon_cb_s.BID;
            xtn.BRESP = vif.mon_cb_s.BRESP;

            analysis_port.write(xtn);
        end
    endtask

    //--------------------------------------------------------------------------
    // READ TRANSACTION COLLECTION
    //--------------------------------------------------------------------------
    task collect_read_data_slave();
        forever begin
            axi_txn xtn = axi_txn::type_id::create("xtn", this);

            // ---------------- AR ----------------
            do @(vif.mon_cb_s);
            while (!(vif.mon_cb_s.ARVALID && vif.mon_cb_s.ARREADY));

            xtn.is_write = 0;

            xtn.ARADDR  = vif.mon_cb_s.ARADDR;
            xtn.ARID    = vif.mon_cb_s.ARID;
            xtn.ARLEN   = vif.mon_cb_s.ARLEN;
            xtn.ARSIZE  = vif.mon_cb_s.ARSIZE;
            xtn.ARBURST = vif.mon_cb_s.ARBURST;

            xtn.RDATA.delete();

            // ---------------- R ----------------
            for (int i = 0; i <= xtn.ARLEN; i++) begin
                do @(vif.mon_cb_s);
                while (!(vif.mon_cb_s.RVALID && vif.mon_cb_s.RREADY));

                xtn.RDATA.push_back(vif.mon_cb_s.RDATA);
                xtn.RID    = vif.mon_cb_s.RID;
                xtn.RRESP  = vif.mon_cb_s.RRESP;

                if (i != xtn.ARLEN && vif.mon_cb_s.RLAST)
                    `uvm_error("SLV_MON_RD", "RLAST asserted early")

                if (i == xtn.ARLEN && !vif.mon_cb_s.RLAST)
                    `uvm_error("SLV_MON_RD", "RLAST missing on final beat")
            end

            analysis_port.write(xtn);
        end
    endtask

endclass
