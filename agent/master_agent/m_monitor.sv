//==============================================================================//
// MASTER MONITOR
// Implementation: Observes AXI4 handshakes and sends transactions
//=============================================================================//
class m_monitor extends uvm_monitor;

    `uvm_component_utils(m_monitor)

    m_config                        m_cfg;
    virtual axi_if                  vif;
   
    // Analysis port to send collected transactions to the scoreboard
    uvm_analysis_port #(axi_txn)    analysis_port;

    extern function new(string name = "m_monitor", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);
    extern task run_phase(uvm_phase phase);

    // READ & WRITE OPERATION TASKS
    extern task collect_write_data();
    extern task collect_read_data();
endclass

// CONSTRUCTOR
function m_monitor::new(string name = "m_monitor", uvm_component parent);
    super.new(name,parent);
    analysis_port = new("analysis_port",this);
endfunction

// BUILD PHASE
function void m_monitor::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(m_config)::get(this,"","m_config",m_cfg))
        `uvm_fatal("MASTER MONITOR","CANNOT GET DATA FROM M_CFG. HAVE YOU SET IT?" )
endfunction

// CONNECT PHASE
function void m_monitor::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vif = m_cfg.vif;
    if(vif==null)
        `uvm_fatal("MASTER MONITOR", "VIF is NULL")
endfunction

// RUN PHASE
task m_monitor::run_phase(uvm_phase phase);
    super.run_phase(phase);
    
    // Using join_none ensures the run_phase does not block on the forever loops.
    // The spawned processes will continue running in the background.
    fork
        collect_write_data();
        collect_read_data();
    join_none
endtask

//****************************************************************************//
// WRITE TRANSACTIONS
// Capturing AW, W, and B Channels
//***************************************************************************//
task m_monitor::collect_write_data();
    axi_txn xtn;
    forever begin
        xtn = axi_txn::type_id::create("xtn", this);

        // CAPTURING ADDRESS CHANNEL
        do begin
            @(vif.mon_cb_m);
        end while(!(vif.mon_cb_m.AWVALID && vif.mon_cb_m.AWREADY));

        xtn.AWADDR  = vif.mon_cb_m.AWADDR;
        xtn.AWID    = vif.mon_cb_m.AWID;
        xtn.AWLEN   = vif.mon_cb_m.AWLEN;
        xtn.AWSIZE  = vif.mon_cb_m.AWSIZE;
        xtn.AWBURST = vif.mon_cb_m.AWBURST;

        // CAPTURING DATA CHANNEL
        for(int i = 0; i <= xtn.AWLEN; i++) begin
            do begin
                @(vif.mon_cb_m);
            end while(!(vif.mon_cb_m.WVALID && vif.mon_cb_m.WREADY));

            xtn.WDATA.push_back(vif.mon_cb_m.WDATA);
            xtn.WSTRB.push_back(vif.mon_cb_m.WSTRB);

            // Protocol Checks for Write Last
            if(i != xtn.AWLEN && vif.mon_cb_m.WLAST)
                `uvm_error("MONITOR_WRITE", "WLAST asserted prematurely")

            if(i == xtn.AWLEN && !vif.mon_cb_m.WLAST)
                `uvm_error("MONITOR_WRITE", "WLAST missing on last beat")
        end

        // CAPTURING RESPONSE CHANNEL
        do begin
            @(vif.mon_cb_m);
        end while(!(vif.mon_cb_m.BVALID && vif.mon_cb_m.BREADY));

        xtn.BID   = vif.mon_cb_m.BID;
        xtn.BRESP = vif.mon_cb_m.BRESP;

        // SEND COMPLETED TRANSACTIONS TO ANALYSIS PORT
        `uvm_info("MONITOR WRITE", "COLLECTED WRITE TRANSACTION", UVM_LOW)
        analysis_port.write(xtn);
    end
endtask

//****************************************************************************//
// READ TRANSACTIONS
// Capturing AR and R Channels
//***************************************************************************//
task m_monitor::collect_read_data();
    axi_txn xtn;
    forever begin
        xtn = axi_txn::type_id::create("xtn", this);
        
        // CAPTURING READ ADDRESS CHANNEL
        do begin
            @(vif.mon_cb_m);
        end while(!(vif.mon_cb_m.ARVALID && vif.mon_cb_m.ARREADY));

        xtn.ARADDR  = vif.mon_cb_m.ARADDR;
        xtn.ARID    = vif.mon_cb_m.ARID;
        xtn.ARLEN   = vif.mon_cb_m.ARLEN;
        xtn.ARSIZE  = vif.mon_cb_m.ARSIZE;
        xtn.ARBURST = vif.mon_cb_m.ARBURST;

        // CAPTURING READ DATA CHANNEL
        for(int i = 0; i <= xtn.ARLEN; i++) begin
            do begin
                @(vif.mon_cb_m);
            end while(!(vif.mon_cb_m.RVALID && vif.mon_cb_m.RREADY));

            xtn.RDATA.push_back(vif.mon_cb_m.RDATA);
            xtn.RID   = vif.mon_cb_m.RID;
            xtn.RRESP = vif.mon_cb_m.RRESP;

            // Protocol Checks for Read Last
            if(i != xtn.ARLEN && vif.mon_cb_m.RLAST)
                `uvm_error("MONITOR_READ", "RLAST asserted prematurely")
                
            if(i == xtn.ARLEN && !vif.mon_cb_m.RLAST)
                `uvm_error("MONITOR_READ", "RLAST missing on last beat")
        end
        
        // SEND COMPLETED READ TRANSACTIONS TO ANALYSIS PORT
        `uvm_info("MONITOR READ", "COLLECTED READ TRANSACTION", UVM_LOW)
        analysis_port.write(xtn);
    end
endtask