//==============================================================================//
// SCOREBOARD
//=============================================================================//
class scoreboard extends uvm_scoreboard;

    `uvm_component_utils(scoreboard)

    env_config                      env_cfg;
    // Virtual interface used strictly for reset monitoring
    virtual axi_if                  vif;

    // Analysis fifos to store data from master and slave
    uvm_tlm_analysis_fifo #(axi_txn) m_fifo;
    uvm_tlm_analysis_fifo #(axi_txn) s_fifo;

    // Associative arrays to store transactions pending matching
    // Keys are the Transaction IDs (AWID/ARID)
    axi_txn m_wr_pending[bit[3:0]][$];
    axi_txn s_wr_pending[bit[3:0]][$];
    axi_txn m_rd_pending[bit[3:0]][$];
    axi_txn s_rd_pending[bit[3:0]][$];

    // Statistics
    int data_verified_count = 0;

    extern function new(string name = "scoreboard", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern task run_phase(uvm_phase phase);
    extern function void check_data(axi_txn m, axi_txn s);
    extern function void report_phase(uvm_phase phase);
endclass

function scoreboard::new(string name = "scoreboard", uvm_component parent);
    super.new(name, parent);
    m_fifo = new("m_fifo", this);
    s_fifo = new("s_fifo", this);
endfunction

function void scoreboard::build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Get environment config
    if(!uvm_config_db #(env_config)::get(this, "", "env_config", env_cfg))
        `uvm_fatal("SCOREBOARD", "CANNOT GET DATA FROM ENV_CFG")
        
    // Get VIF directly for reset awareness (Avoids hardcoding m_cfg[0])
    if(!uvm_config_db #(virtual axi_if)::get(this, "", "vif", vif))
        `uvm_fatal("SCOREBOARD", "CANNOT GET VIF FOR RESET MONITORING")
endfunction

task scoreboard::run_phase(uvm_phase phase);
    super.run_phase(phase);

    forever begin
        // Wait for reset release (Active Low)
        wait(vif.aresetn === 1);

        fork
            // Process A: Independent Master Collection
            forever begin
                axi_txn xtn;
                m_fifo.get(xtn);
                `uvm_info("MASTER SCOREBOARD", $sformatf("Retrieved Master Xtn: \n %s", xtn.sprint()), UVM_HIGH)
                
                if(xtn.WDATA.size() != 0) begin
                    if(s_wr_pending.exists(xtn.AWID) && s_wr_pending[xtn.AWID].size() > 0)
                        check_data(xtn, s_wr_pending[xtn.AWID].pop_front());
                    else
                        m_wr_pending[xtn.AWID].push_back(xtn);
                end else begin
                    if(s_rd_pending.exists(xtn.ARID) && s_rd_pending[xtn.ARID].size() > 0)
                        check_data(xtn, s_rd_pending[xtn.ARID].pop_front());
                    else
                        m_rd_pending[xtn.ARID].push_back(xtn);
                end
            end

            // Process B: Independent Slave Collection
            forever begin
                axi_txn xtn;
                s_fifo.get(xtn);
                `uvm_info("SLAVE SCOREBOARD", $sformatf("Retrieved Slave Xtn: \n %s", xtn.sprint()), UVM_HIGH)

                if(xtn.WDATA.size() != 0) begin
                    if(m_wr_pending.exists(xtn.AWID) && m_wr_pending[xtn.AWID].size() > 0)
                        check_data(m_wr_pending[xtn.AWID].pop_front(), xtn);
                    else
                        s_wr_pending[xtn.AWID].push_back(xtn);
                end else begin
                    if(m_rd_pending.exists(xtn.ARID) && m_rd_pending[xtn.ARID].size() > 0)
                        check_data(m_rd_pending[xtn.ARID].pop_front(), xtn);
                    else
                        s_rd_pending[xtn.ARID].push_back(xtn);
                end
            end

            // Process C: Reset Monitor
            begin
                wait(vif.aresetn === 0);
                `uvm_info("SCOREBOARD", "RESET DETECTED: Flushing Buffers", UVM_LOW)
                m_fifo.flush();
                s_fifo.flush();
                m_wr_pending.delete();
                s_wr_pending.delete();
                m_rd_pending.delete();
                s_rd_pending.delete();
            end
        join_any
        disable fork;
    end
endtask

function void scoreboard::check_data(axi_txn m, axi_txn s);
    bit match = 1;

    `uvm_info("SCOREBOARD", "PERFORMING COMPARISON", UVM_LOW)

    // WRITE COMPARISON
    if(m.WDATA.size() != 0) begin
        if(m.AWADDR !== s.AWADDR) begin
            match = 0;
            `uvm_error("SCB_WR_ADDR", $sformatf("MISMATCH! M_ADDR: %h, S_ADDR: %h", m.AWADDR, s.AWADDR))
        end else `uvm_info("SCOREBOARD", "WRITE ADDRESS MATCHED", UVM_LOW)

        if(m.AWID !== s.AWID) begin
            match = 0;
            `uvm_error("SCB_WR_ID", $sformatf("MISMATCH! M_AWID: %h, S_AWID: %h", m.AWID, s.AWID))
        end else `uvm_info("SCOREBOARD", "WRITE ADDR ID MATCHED", UVM_LOW)
                
        if (m.WDATA.size() != s.WDATA.size()) begin
            match = 0;
            `uvm_error("SCB_WR_LEN", "WDATA size mismatch!")
        end else begin
            foreach (m.WDATA[i]) begin
                if (m.WDATA[i] !== s.WDATA[i]) begin
                    match = 0;
                    `uvm_error("SCB_WR_DATA", $sformatf("Beat %0d Data Mismatch! M:%h S:%h", i, m.WDATA[i], s.WDATA[i]))
                end
                if (m.WSTRB[i] !== s.WSTRB[i]) begin
                    match = 0;
                    `uvm_error("SCB_WR_STRB", $sformatf("Beat %0d Strobe Mismatch! M:%b S:%b", i, m.WSTRB[i], s.WSTRB[i]))
                end
            end
        end
    end 

    // READ COMPARISON
    if(m.RDATA.size() != 0) begin
        if(m.ARADDR !== s.ARADDR) begin
            match = 0;
            `uvm_error("SCB_RD_ADDR", $sformatf("MISMATCH! M_ADDR: %h, S_ADDR: %h", m.ARADDR, s.ARADDR))
        end else `uvm_info("SCOREBOARD", "READ ADDRESS MATCHED", UVM_LOW)

        if(m.ARID !== s.ARID) begin
            match = 0;
            `uvm_error("SCB_RD_ID", $sformatf("MISMATCH! M_ARID: %h, S_ARID: %h", m.ARID, s.ARID))
        end else `uvm_info("SCOREBOARD", "READ ADDR ID MATCHED", UVM_LOW)
                
        if (m.RDATA.size() != s.RDATA.size()) begin
            match = 0;
            `uvm_error("SCB_RD_LEN", "RDATA size mismatch!")
        end else begin
            foreach (m.RDATA[i]) begin
                if (m.RDATA[i] !== s.RDATA[i]) begin
                    match = 0;
                    `uvm_error("SCB_RD_DATA", $sformatf("Beat %0d Mismatch! M:%h S:%h", i, m.RDATA[i], s.RDATA[i]))
                end
            end
        end
    end 

    if (match) begin
        data_verified_count++;
        `uvm_info("SCB_MATCH", "TRANSACTION MATCHED SUCCESSFULLY", UVM_LOW)
    end
endfunction

function void scoreboard::report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB_REPORT", "--------------------------------------------------", UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf(" TOTAL MATCHES: %0d", data_verified_count), UVM_NONE)
    `uvm_info("SCB_REPORT", "--------------------------------------------------", UVM_NONE)
endfunction