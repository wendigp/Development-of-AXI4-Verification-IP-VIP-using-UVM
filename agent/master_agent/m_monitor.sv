//==============================================================================
// AXI MASTER MONITOR - FINAL (QUEUE CORRECT)
// Fixes:
// 1. Removed illegal new[] usage on queues
// 2. Uses delete() + push_back() for burst data
// 3. Sets is_write for subscriber / scoreboard
// 4. Reset-safe fork/join_any model preserved
//==============================================================================

class m_monitor extends uvm_monitor;

    `uvm_component_utils(m_monitor)

    m_config        m_cfg;
    virtual axi_if  vif;

    uvm_analysis_port #(axi_txn) analysis_port;

    //--------------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------------
    function new(string name = "m_monitor", uvm_component parent);
        super.new(name, parent);
        analysis_port = new("analysis_port", this);
    endfunction

    //--------------------------------------------------------------------------
    // Build
    //--------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(m_config)::get(this, "", "m_config", m_cfg))
            `uvm_fatal("MASTER_MONITOR", "Cannot get m_config")
    endfunction

    //--------------------------------------------------------------------------
    // Connect
    //--------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        vif = m_cfg.vif;
        if (vif == null)
            `uvm_fatal("MASTER_MONITOR", "VIF is NULL")
    endfunction

    //--------------------------------------------------------------------------
    // Run
    //--------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        forever begin
            // Wait for reset release
            wait (vif.ARESETn === 1);

            fork : monitor_threads
                begin
                    fork
                        collect_write_data();
                        collect_read_data();
                    join
                end
                begin
                    wait (vif.ARESETn === 0);
                end
            join_any

            // Kill collection on reset
            disable monitor_threads;
            `uvm_info("MASTER_MONITOR",
                      "Reset detected: Collection threads terminated safely",
                      UVM_HIGH)
        end
    endtask

    //--------------------------------------------------------------------------
    // WRITE TRANSACTION COLLECTION
    //--------------------------------------------------------------------------
    task collect_write_data();
        forever begin
            axi_txn xtn = axi_txn::type_id::create("xtn", this);

            // ---------------- AW ----------------
            do @(vif.mon_cb_m);
            while (!(vif.mon_cb_m.AWVALID && vif.mon_cb_m.AWREADY));

            xtn.is_write = 1;

            xtn.AWADDR  = vif.mon_cb_m.AWADDR;
            xtn.AWID    = vif.mon_cb_m.AWID;
            xtn.AWLEN   = vif.mon_cb_m.AWLEN;
            xtn.AWSIZE  = vif.mon_cb_m.AWSIZE;
            xtn.AWBURST = vif.mon_cb_m.AWBURST;

            xtn.WDATA.delete();
            xtn.WSTRB.delete();

            // ---------------- W ----------------
            for (int i = 0; i <= xtn.AWLEN; i++) begin
                do @(vif.mon_cb_m);
                while (!(vif.mon_cb_m.WVALID && vif.mon_cb_m.WREADY));

                xtn.WDATA.push_back(vif.mon_cb_m.WDATA);
                xtn.WSTRB.push_back(vif.mon_cb_m.WSTRB);

                if (i != xtn.AWLEN && vif.mon_cb_m.WLAST)
                    `uvm_error("MASTER_MON_WRITE", "WLAST asserted early")

                if (i == xtn.AWLEN && !vif.mon_cb_m.WLAST)
                    `uvm_error("MASTER_MON_WRITE", "WLAST missing on final beat")
            end

            // ---------------- B ----------------
            do @(vif.mon_cb_m);
            while (!(vif.mon_cb_m.BVALID && vif.mon_cb_m.BREADY));

            xtn.BID   = vif.mon_cb_m.BID;
            xtn.BRESP = vif.mon_cb_m.BRESP;

            analysis_port.write(xtn);
        end
    endtask

    //--------------------------------------------------------------------------
    // READ TRANSACTION COLLECTION
    //--------------------------------------------------------------------------
    task collect_read_data();
        forever begin
            axi_txn xtn = axi_txn::type_id::create("xtn", this);

            // ---------------- AR ----------------
            do @(vif.mon_cb_m);
            while (!(vif.mon_cb_m.ARVALID && vif.mon_cb_m.ARREADY));

            xtn.is_write = 0;

            xtn.ARADDR  = vif.mon_cb_m.ARADDR;
            xtn.ARID    = vif.mon_cb_m.ARID;
            xtn.ARLEN   = vif.mon_cb_m.ARLEN;
            xtn.ARSIZE  = vif.mon_cb_m.ARSIZE;
            xtn.ARBURST = vif.mon_cb_m.ARBURST;

            xtn.RDATA.delete();

            // ---------------- R ----------------
            for (int i = 0; i <= xtn.ARLEN; i++) begin
                do @(vif.mon_cb_m);
                while (!(vif.mon_cb_m.RVALID && vif.mon_cb_m.RREADY));

                xtn.RDATA.push_back(vif.mon_cb_m.RDATA);
                xtn.RID    = vif.mon_cb_m.RID;
                xtn.RRESP  = vif.mon_cb_m.RRESP;

                if (i != xtn.ARLEN && vif.mon_cb_m.RLAST)
                    `uvm_error("MASTER_MON_READ", "RLAST asserted early")

                if (i == xtn.ARLEN && !vif.mon_cb_m.RLAST)
                    `uvm_error("MASTER_MON_READ", "RLAST missing on final beat")
            end

            analysis_port.write(xtn);
        end
    endtask

endclass
