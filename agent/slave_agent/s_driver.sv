//==============================================================================//
// SLAVE DRIVER (FULLY REACTIVE)
// Implementation: Monitors interface for Master requests and responds autonomously
//=============================================================================//
class s_driver extends uvm_driver #(axi_txn);

    `uvm_component_utils(s_driver)

    s_config                        s_cfg;
    virtual axi_if                  vif;

    // Byte-addressable slave memory
    bit [7:0] slave_mem [bit [31:0]];

    extern function new(string name = "s_driver", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);
    extern task run_phase(uvm_phase phase);
    
    // TASK FOR CHANNEL HANDLING
    extern task handle_write_requests();
    extern task handle_read_requests();

    // TASKS FOR WRITE OPERATION (REACTIVE)
    extern task write_addr_phase(axi_txn xtn);
    extern task write_data_phase(axi_txn xtn);
    extern task write_response_phase(axi_txn xtn);
    
    // TASKS FOR READ OPERATION (REACTIVE)
    extern task read_addr_phase(axi_txn xtn);
    extern task read_data_phase(axi_txn xtn);

endclass

//==============================================================================//
// CONSTRUCTOR
//==============================================================================//
function s_driver::new(string name = "s_driver", uvm_component parent);
    super.new(name, parent);
endfunction

//==============================================================================//
// BUILD PHASE
//==============================================================================//
function void s_driver::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(s_config)::get(this, "", "s_config", s_cfg))
        `uvm_fatal("SLAVE_DRIVER", "CANNOT GET s_config")
endfunction

//==============================================================================//
// CONNECT PHASE
//==============================================================================//
function void s_driver::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vif = s_cfg.vif;
    if(vif == null)
        `uvm_fatal("SLAVE_DRIVER", "VIF IS NULL")
endfunction

//==============================================================================//
// RUN PHASE
//==============================================================================//
task s_driver::run_phase(uvm_phase phase);
    super.run_phase(phase);

    // Initial State Reset: Slave is idle
    vif.drv_cb_s.AWREADY <= 0;
    vif.drv_cb_s.WREADY  <= 0;
    vif.drv_cb_s.BVALID  <= 0;
    vif.drv_cb_s.ARREADY <= 0;
    vif.drv_cb_s.RVALID  <= 0;
    vif.drv_cb_s.RLAST   <= 0;

    // AXI is full-duplex: handle Read and Write independently without blocking
    fork
        handle_write_requests();
        handle_read_requests();
    join_none
endtask

//==============================================================================//
// WRITE REQUEST HANDLER
//==============================================================================//
task s_driver::handle_write_requests();
    axi_txn xtn;
    forever begin
        // RESET GUARD: Ensure signals are zeroed during reset
        if (!vif.rst_n) begin
            vif.drv_cb_s.AWREADY <= 0;
            vif.drv_cb_s.WREADY  <= 0;
            vif.drv_cb_s.BVALID  <= 0;
            @(posedge vif.rst_n);
        end

        xtn = axi_txn::type_id::create("xtn");
        
        // 1. Capture address FIRST
        write_addr_phase(xtn);
        
        // 2. Then accept data beats
        write_data_phase(xtn);
        
        // 3. Autonomous Response Generation
        xtn.BRESP = 2'b00; // OKAY
        
        // 4. Drive Response back to Master
        write_response_phase(xtn);
    end
endtask

//==============================================================================//
// READ REQUEST HANDLER
//==============================================================================//
task s_driver::handle_read_requests();
    axi_txn xtn;
    forever begin
        // RESET GUARD: Ensure signals are zeroed during reset
        if (!vif.rst_n) begin
            vif.drv_cb_s.ARREADY <= 0;
            vif.drv_cb_s.RVALID  <= 0;
            vif.drv_cb_s.RLAST   <= 0;
            @(posedge vif.rst_n);
        end

        xtn = axi_txn::type_id::create("xtn");
        
        // 1. Capture the Address/Control from Master
        read_addr_phase(xtn);
        
        // 2. Autonomous Data Generation
        xtn.RRESP = 2'b00; // OKAY
        
        // 3. Drive Data Burst back to Master
        read_data_phase(xtn);
    end
endtask

//******************************************************************************//
// WRITE ADDRESS PHASE
//******************************************************************************//
task s_driver::write_addr_phase(axi_txn xtn);
    @(vif.drv_cb_s);
    vif.drv_cb_s.AWREADY <= 1;

    wait(vif.drv_cb_s.AWVALID);

    // Capture metadata from interface IMMEDIATELY during handshake
    xtn.AWID   = vif.drv_cb_s.AWID; 
    xtn.AWADDR = vif.drv_cb_s.AWADDR;
    xtn.AWLEN  = vif.drv_cb_s.AWLEN;

    @(vif.drv_cb_s);
    vif.drv_cb_s.AWREADY <= 0;
endtask

//******************************************************************************//
// WRITE DATA PHASE
//******************************************************************************//
task s_driver::write_data_phase(axi_txn xtn);
    bit [31:0] current_addr;
    int beat_count;
    bit last_seen;
    
    current_addr = xtn.AWADDR;
    beat_count   = 0;
    last_seen    = 0;

    while (!last_seen) begin
        // SAFE HANDSHAKE: Assert WREADY before sampling WVALID
        vif.drv_cb_s.WREADY <= 1;
        
        do @(vif.drv_cb_s);
        while (vif.drv_cb_s.WVALID !== 1);

        // Store data using WSTRB
        for (int i = 0; i < 4; i++) begin
            if (vif.drv_cb_s.WSTRB[i]) begin
                slave_mem[current_addr + i] = vif.drv_cb_s.WDATA[(i*8) +: 8];
            end
        end

        // Burst checks
        if (vif.drv_cb_s.WLAST) begin
            last_seen = 1;
            if (beat_count != xtn.AWLEN) begin
                `uvm_error("AXI_WLAST_ERR", 
                    $sformatf("Early WLAST: expected %0d beats (AWLEN=%0d), got %0d", 
                              xtn.AWLEN+1, xtn.AWLEN, beat_count+1))
            end
        end else if (beat_count == xtn.AWLEN) begin
            `uvm_error("AXI_WLAST_ERR", "Missing WLAST on final beat")
            last_seen = 1; // Force termination to prevent hanging
        end

        beat_count++;
        current_addr += 4; 
    end

    // End of data phase handshaking - deassert WREADY
    vif.drv_cb_s.WREADY <= 0;
    @(vif.drv_cb_s);
endtask

//******************************************************************************//
// WRITE RESPONSE PHASE
//******************************************************************************//
task s_driver::write_response_phase(axi_txn xtn);
    @(vif.drv_cb_s);
    vif.drv_cb_s.BVALID <= 1;
    vif.drv_cb_s.BRESP  <= xtn.BRESP;
    vif.drv_cb_s.BID    <= xtn.AWID; 

    wait(vif.drv_cb_s.BREADY);
    @(vif.drv_cb_s);

    vif.drv_cb_s.BVALID <= 0;
endtask

//******************************************************************************//
// READ ADDRESS PHASE
//******************************************************************************//
task s_driver::read_addr_phase(axi_txn xtn);
    @(vif.drv_cb_s);
    vif.drv_cb_s.ARREADY <= 1;

    wait(vif.drv_cb_s.ARVALID);

    // Capture metadata from interface
    xtn.ARID   = vif.drv_cb_s.ARID;
    xtn.ARADDR = vif.drv_cb_s.ARADDR;
    xtn.ARLEN  = vif.drv_cb_s.ARLEN;

    @(vif.drv_cb_s);
    vif.drv_cb_s.ARREADY <= 0;
endtask

//******************************************************************************//
// READ DATA PHASE
//******************************************************************************//
task s_driver::read_data_phase(axi_txn xtn);
    bit [31:0] current_addr;
    bit [31:0] data_word;

    current_addr = xtn.ARADDR;

    for (int i = 0; i <= xtn.ARLEN; i++) begin
        // Async reset check inside loop
        if (!vif.rst_n) begin
            vif.drv_cb_s.RVALID <= 0;
            vif.drv_cb_s.RLAST  <= 0;
            return;
        end

        data_word = 32'h0;
        for (int b = 0; b < 4; b++) begin
            if (slave_mem.exists(current_addr + b))
                data_word[(b*8) +: 8] = slave_mem[current_addr + b];
            else
                data_word[(b*8) +: 8] = $urandom;
        end

        vif.drv_cb_s.RVALID <= 1;
        vif.drv_cb_s.RID    <= xtn.ARID;
        vif.drv_cb_s.RDATA  <= data_word;
        vif.drv_cb_s.RRESP  <= xtn.RRESP;
        vif.drv_cb_s.RLAST  <= (i == xtn.ARLEN);

        do @(vif.drv_cb_s);
        while (!vif.drv_cb_s.RREADY);

        current_addr += 4;
    end

    vif.drv_cb_s.RVALID <= 0;
    vif.drv_cb_s.RLAST  <= 0;
    @(vif.drv_cb_s);
endtask