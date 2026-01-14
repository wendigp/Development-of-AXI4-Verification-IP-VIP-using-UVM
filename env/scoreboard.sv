//==============================================================================//
// RAW MEMORY SCOREBOARD
// Implementation: Maintains a Golden Memory Model (Associative Array)
// Logic: 
//   - On Write: Update the golden_mem model with WDATA based on WSTRB
//   - On Read: Compare retrieved RDATA against the golden_mem model
// Features: Supports out-of-order transactions and reset-based memory clearing
//=============================================================================//
class scoreboard extends uvm_scoreboard;

    `uvm_component_utils(scoreboard)

    env_config                      env_cfg;
    virtual axi_if                  vif;

    // Analysis fifos to store data from monitors
    uvm_tlm_analysis_fifo #(axi_txn) m_fifo;
    uvm_tlm_analysis_fifo #(axi_txn) s_fifo;

    // GOLDEN MEMORY MODEL: Sparse associative array (Byte Address -> Byte Data)
    bit [7:0] golden_mem [bit [31:0]];

    // Statistics
    int write_count = 0;
    int read_check_count = 0;
    int error_count = 0;

    extern function new(string name = "scoreboard", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern task run_phase(uvm_phase phase);
    extern function void process_write(axi_txn xtn);
    extern function void process_read(axi_txn xtn);
    extern function bit [31:0] get_next_addr(bit [31:0] cur_addr, bit [1:0] b_type, int len);
    extern function void report_phase(uvm_phase phase);
endclass

function scoreboard::new(string name = "scoreboard", uvm_component parent);
    super.new(name, parent);
    m_fifo = new("m_fifo", this);
    s_fifo = new("s_fifo", this);
endfunction

function void scoreboard::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(env_config)::get(this, "", "env_config", env_cfg))
        `uvm_fatal("SCOREBOARD", "CANNOT GET ENV_CFG")
    if(!uvm_config_db #(virtual axi_if)::get(this, "", "vif", vif))
        `uvm_fatal("SCOREBOARD", "CANNOT GET VIF")
endfunction

task scoreboard::run_phase(uvm_phase phase);
    super.run_phase(phase);

    forever begin
        wait(vif.ARESETn === 1);

        fork
            // Process A: Monitor Master (Writer/Initiator Side)
            forever begin
                axi_txn m_xtn;
                m_fifo.get(m_xtn);
                if (m_xtn.WDATA.size() > 0) process_write(m_xtn);
            end

            // Process B: Monitor Slave (Responder Side)
            forever begin
                axi_txn s_xtn;
                s_fifo.get(s_xtn);
                if (s_xtn.RDATA.size() > 0) process_read(s_xtn);
            end

            // Process C: Reset Monitor (Synchronous structured exit)
            begin
                wait(vif.ARESETn === 0);
                `uvm_info("SCOREBOARD", "RESET DETECTED: Clearing Golden Memory", UVM_LOW)
            end
        join_any
        
        // ISSUE 1 FIX: Clean termination of all processes on reset
        disable fork;
        golden_mem.delete();
        m_fifo.flush();
        s_fifo.flush();
    end
endtask

//==============================================================================//
// PROCESS WRITE: Update the Golden Model
//==============================================================================//
function void scoreboard::process_write(axi_txn xtn);
    bit [31:0] addr = xtn.AWADDR;
    
    `uvm_info("SCB_WRITE", $sformatf("Updating Model: Addr=%h, Type=%b, Beats=%0d", addr, xtn.AWBURST, xtn.WDATA.size()), UVM_MEDIUM)

    foreach (xtn.WDATA[i]) begin
        for (int j = 0; j < 4; j++) begin
            if (xtn.WSTRB[i][j]) begin
                golden_mem[addr + j] = xtn.WDATA[i][(j*8) +: 8];
            end
        end
        // ISSUE 4 FIX: Dynamic address calculation based on burst type
        addr = get_next_addr(addr, xtn.AWBURST, xtn.AWLEN);
    end
    write_count++;
endfunction

//==============================================================================//
// PROCESS READ: Verify against the Golden Model
//==============================================================================//
function void scoreboard::process_read(axi_txn xtn);
    bit [31:0] addr = xtn.ARADDR;
    bit [7:0] expected_byte;
    bit mismatch = 0;

    `uvm_info("SCB_READ", $sformatf("Verifying Read: Addr=%h, ID=%h", addr, xtn.RID), UVM_MEDIUM)

    foreach (xtn.RDATA[i]) begin
        for (int j = 0; j < 4; j++) begin
            bit [7:0] actual_byte = xtn.RDATA[i][(j*8) +: 8];
            
            if (golden_mem.exists(addr + j)) begin
                expected_byte = golden_mem[addr + j];
                if (actual_byte !== expected_byte) begin
                    `uvm_error("SCB_MEM_MISMATCH", 
                        $sformatf("Read Mismatch at Addr %h! Expected: %h, Got: %h", 
                        addr + j, expected_byte, actual_byte))
                    mismatch = 1;
                end
            end else begin
                `uvm_warning("SCB_UNINIT_READ", $sformatf("Read from uninitialized Addr %h", addr + j))
            end
        end
        // ISSUE 4 FIX: Dynamic address calculation for read burst
        addr = get_next_addr(addr, xtn.ARBURST, xtn.ARLEN);
    end

    if (!mismatch) read_check_count++;
    else           error_count++;
endfunction

// Helper to calculate address based on AXI Burst Types (FIXES ISSUE 4)
function bit [31:0] scoreboard::get_next_addr(bit [31:0] cur_addr, bit [1:0] b_type, int len);
    case(b_type)
        2'b00: return cur_addr; // FIXED burst
        2'b01: return cur_addr + 4; // INCR burst
        2'b10: begin // WRAP burst (Simplified logic for 4-byte aligned)
            bit [31:0] wrap_size = (len + 1) * 4;
            bit [31:0] base_addr = (cur_addr / wrap_size) * wrap_size;
            bit [31:0] next_addr = cur_addr + 4;
            if (next_addr >= base_addr + wrap_size) return base_addr;
            else return next_addr;
        end
        default: return cur_addr + 4;
    endcase
endfunction

function void scoreboard::report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB_REPORT", "==================================================", UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf(" TOTAL WRITES CAPTURED: %0d", write_count), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf(" TOTAL READS VERIFIED: %0d", read_check_count), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf(" TOTAL ERRORS FOUND:    %0d", error_count), UVM_NONE)
    `uvm_info("SCB_REPORT", "==================================================", UVM_NONE)
endfunction