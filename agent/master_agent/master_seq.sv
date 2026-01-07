//==============================================================================//
// AXI MASTER SEQUENCE
// Implementation: Generates various AXI4 transaction patterns
// Updated: Improved constraints for protocol correctness and targeted coverage
//=============================================================================//

//==============================================================================//
// BASE SEQUENCE
//==============================================================================//
class master_base_seq extends uvm_sequence #(axi_txn);

    `uvm_object_utils(master_base_seq)

    function new(string name = "master_base_seq");
        super.new(name);
    endfunction

    extern virtual task body();

endclass

task master_base_seq::body();
    `uvm_info("BASE_SEQ", "Starting Master Base Sequence", UVM_LOW)
    
    req = axi_txn::type_id::create("req");
    start_item(req);
    
    // Constraint: Ensure item is strictly Read or Write and align the active address
    if (!req.randomize() with { 
        is_write inside {0,1};
        (is_write == 1) -> (AWADDR % 4 == 0);
        (is_write == 0) -> (ARADDR % 4 == 0);
    }) begin
        `uvm_fatal("SEQ", "Randomization failed")
    end
    
    finish_item(req);
endtask

//==============================================================================//
// INCR BURST SEQUENCE
//==============================================================================//
class incr_burst_seq extends master_base_seq;

    `uvm_object_utils(incr_burst_seq)

    int num_txns = 5;

    function new(string name = "incr_burst_seq");
        super.new(name);
    endfunction

    extern virtual task body();
endclass

task incr_burst_seq::body();
    repeat(num_txns) begin
        // 1. Explicit Write Transaction
        req = axi_txn::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { 
            is_write == 1;
            AWBURST == 2'b01; // INCR
            AWLEN inside {[1:15]}; 
            AWADDR % 4 == 0;
        }) begin
            `uvm_fatal("SEQ", "Write INCR Randomization failed")
        end
        finish_item(req);

        // 2. Explicit Read Transaction
        req = axi_txn::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { 
            is_write == 0;
            ARBURST == 2'b01; // INCR
            ARLEN inside {[1:15]}; 
            ARADDR % 4 == 0;
        }) begin
            `uvm_fatal("SEQ", "Read INCR Randomization failed")
        end
        finish_item(req);
    end
endtask

//==============================================================================//
// READ-AFTER-WRITE (RAW) SEQUENCE
// Logic: Forces same address, burst, and length to trigger hazard logic
// Updated: Excluded FIXED (2'b00) burst to match subscriber coverage logic
//==============================================================================//
class raw_hazard_seq extends master_base_seq;

    `uvm_object_utils(raw_hazard_seq)

    function new(string name = "raw_hazard_seq");
        super.new(name);
    endfunction

    extern virtual task body();
endclass

task raw_hazard_seq::body();
    bit [31:0] shared_addr;
    bit [3:0]  shared_len;
    bit [1:0]  shared_burst;
    bit [2:0]  shared_size;
    
    // 1. Perform Write and capture all parameters
    // Constraint: AWBURST != 2'b00 to ensure the subscriber processes the RAW check
    req = axi_txn::type_id::create("req");
    start_item(req);
    if (!req.randomize() with { 
        is_write == 1; 
        AWADDR % 4 == 0;
        AWBURST inside {2'b01, 2'b10}; // INCR or WRAP only
    }) begin
         `uvm_fatal("SEQ", "RAW-Write Randomization failed")
    end
    
    shared_addr  = req.AWADDR;
    shared_len   = req.AWLEN;
    shared_burst = req.AWBURST;
    shared_size  = req.AWSIZE;
    
    finish_item(req);

    // 2. Perform Read matching the EXACT parameters of the write
    req = axi_txn::type_id::create("req");
    start_item(req);
    if (!req.randomize() with { 
        is_write == 0; 
        ARADDR  == shared_addr; 
        ARLEN   == shared_len;
        ARBURST == shared_burst;
        ARSIZE  == shared_size;
    }) begin
         `uvm_fatal("SEQ", "RAW-Read Randomization failed")
    end
    finish_item(req);
    
    `uvm_info("SEQ", $sformatf("RAW Hazard Sequence Complete: Addr=%h, Len=%0d, Burst=%b", shared_addr, shared_len, shared_burst), UVM_LOW)
endtask

//==============================================================================//
// NARROW TRANSFER SEQUENCE
// Logic: Forces transfer size < bus width AND ensures aligned addresses
//==============================================================================//
class narrow_transfer_seq extends master_base_seq;

    `uvm_object_utils(narrow_transfer_seq)

    function new(string name = "narrow_transfer_seq");
        super.new(name);
    endfunction

    extern virtual task body();
endclass

task narrow_transfer_seq::body();
    repeat(5) begin
        req = axi_txn::type_id::create("req");
        start_item(req);
        
        // Randomize size to 1-byte (000) or 2-byte (001)
        // Ensure address is aligned to the chosen size
        if (!req.randomize() with { 
            AWSIZE < 3'b010; 
            ARSIZE < 3'b010;
            AWBURST == 2'b01; 
            (AWSIZE == 3'b000) -> (AWADDR % 1 == 0);
            (AWSIZE == 3'b001) -> (AWADDR % 2 == 0);
            (ARSIZE == 3'b000) -> (ARADDR % 1 == 0);
            (ARSIZE == 3'b001) -> (ARADDR % 2 == 0);
        }) begin
            `uvm_fatal("SEQ", "Narrow Randomization failed")
        end
        finish_item(req);
    end
endtask

//==============================================================================//
// FIXED BURST SEQUENCE
//==============================================================================//
class fixed_burst_seq extends master_base_seq;

    `uvm_object_utils(fixed_burst_seq)

    function new(string name = "fixed_burst_seq");
        super.new(name);
    endfunction

    extern virtual task body();
endclass

task fixed_burst_seq::body();
    req = axi_txn::type_id::create("req");
    start_item(req);
    if (!req.randomize() with { 
        AWBURST == 2'b00; // FIXED
        ARBURST == 2'b00;
        AWLEN < 16;
        AWADDR % 4 == 0;
    }) begin
        `uvm_fatal("SEQ", "Fixed Randomization failed")
    end
    finish_item(req);
endtask

//==============================================================================//
// WRAPPING BURST SEQUENCE
//==============================================================================//
class wrap_burst_seq extends master_base_seq;

    `uvm_object_utils(wrap_burst_seq)

    function new(string name = "wrap_burst_seq");
        super.new(name);
    endfunction

    extern virtual task body();
endclass

task wrap_burst_seq::body();
    req = axi_txn::type_id::create("req");
    start_item(req);
    // Wrap rules: Aligned address is mandatory. Length must be 2, 4, 8, or 16.
    if (!req.randomize() with { 
        AWBURST == 2'b10; // WRAP
        AWLEN inside {1, 3, 7, 15}; 
        AWADDR % 4 == 0; 
    }) begin
        `uvm_fatal("SEQ", "Wrap Randomization failed")
    end
    finish_item(req);
endtask