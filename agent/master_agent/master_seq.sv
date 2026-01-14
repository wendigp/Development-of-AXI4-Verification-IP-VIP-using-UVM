//==============================================================================//
// AXI MASTER SEQUENCES (FIXED)
//==============================================================================//

//==============================================================================//
// BASE SEQUENCE
//==============================================================================//
class master_base_seq extends uvm_sequence #(axi_txn);
    `uvm_object_utils(master_base_seq)

    function new(string name = "master_base_seq");
        super.new(name);
    endfunction

    virtual task body();
        req = axi_txn::type_id::create("req");
        start_item(req);

        // Decide direction explicitly
        req.is_write = $urandom_range(0,1);

        if (!req.randomize() with {
            (req.is_write == 1) -> (AWADDR % 4 == 0);
            (req.is_write == 0) -> (ARADDR % 4 == 0);
        }) begin
            `uvm_fatal("SEQ", "Base sequence randomization failed")
        end

        finish_item(req);
    endtask
endclass


//==============================================================================//
// INCR BURST SEQUENCE (FIXED - Write-Then-Read Same Address)
//==============================================================================//
class incr_burst_seq extends master_base_seq;
    `uvm_object_utils(incr_burst_seq)

    int num_txns = 5;

    function new(string name = "incr_burst_seq");
        super.new(name);
    endfunction

    virtual task body();
        repeat (num_txns) begin
            bit [31:0] shared_addr;
            bit [7:0]  shared_len;
            bit [2:0]  shared_size;
            
            // ===== WRITE TRANSACTION =====
            req = axi_txn::type_id::create("req");
            start_item(req);
            req.is_write = 1;

            if (!req.randomize() with {
                AWBURST == 2'b01;          // INCR
                AWLEN inside {[1:15]};     // Burst length
                AWADDR % 4 == 0;           // Aligned
            }) begin
                `uvm_fatal("SEQ", "Write INCR randomization failed")
            end
            
            // Save parameters for matching read
            shared_addr = req.AWADDR;
            shared_len  = req.AWLEN;
            shared_size = req.AWSIZE;
            
            finish_item(req);
            
            `uvm_info("INCR_SEQ", $sformatf("Write to addr=0x%0h, len=%0d", shared_addr, shared_len), UVM_MEDIUM)

            // ===== READ TRANSACTION (SAME ADDRESS & LENGTH) =====
            req = axi_txn::type_id::create("req");
            start_item(req);
            req.is_write = 0;

            if (!req.randomize() with {
                ARBURST == 2'b01;          // INCR
                ARADDR  == shared_addr;    // SAME address as write
                ARLEN   == shared_len;     // SAME length as write
                ARSIZE  == shared_size;    // SAME size as write
            }) begin
                `uvm_fatal("SEQ", "Read INCR randomization failed")
            end
            finish_item(req);
            
            `uvm_info("INCR_SEQ", $sformatf("Read from addr=0x%0h, len=%0d", shared_addr, shared_len), UVM_MEDIUM)
        end
    endtask
endclass


//==============================================================================//
// READ-AFTER-WRITE (RAW) SEQUENCE
//==============================================================================//
class raw_hazard_seq extends master_base_seq;
    `uvm_object_utils(raw_hazard_seq)

    function new(string name = "raw_hazard_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] shared_addr;
        bit [3:0]  shared_len;
        bit [1:0]  shared_burst;
        bit [2:0]  shared_size;

        // WRITE
        req = axi_txn::type_id::create("req");
        start_item(req);
        req.is_write = 1;

        if (!req.randomize() with {
            AWADDR % 4 == 0;
            AWBURST inside {2'b01, 2'b10};
        }) begin
            `uvm_fatal("SEQ", "RAW write randomization failed")
        end

        shared_addr  = req.AWADDR;
        shared_len   = req.AWLEN;
        shared_burst = req.AWBURST;
        shared_size  = req.AWSIZE;

        finish_item(req);

        // READ (same parameters)
        req = axi_txn::type_id::create("req");
        start_item(req);
        req.is_write = 0;

        if (!req.randomize() with {
            ARADDR  == shared_addr;
            ARLEN   == shared_len;
            ARBURST == shared_burst;
            ARSIZE  == shared_size;
        }) begin
            `uvm_fatal("SEQ", "RAW read randomization failed")
        end
        finish_item(req);
    endtask
endclass


//==============================================================================//
// NARROW TRANSFER SEQUENCE
//==============================================================================//
class narrow_transfer_seq extends master_base_seq;
    `uvm_object_utils(narrow_transfer_seq)

    function new(string name = "narrow_transfer_seq");
        super.new(name);
    endfunction

    virtual task body();
        repeat (5) begin
            req = axi_txn::type_id::create("req");
            start_item(req);
            req.is_write = 1;

            if (!req.randomize() with {
                AWSIZE inside {3'b000, 3'b001};
                AWBURST == 2'b01;
                (AWSIZE == 3'b000) -> (AWADDR % 1 == 0);
                (AWSIZE == 3'b001) -> (AWADDR % 2 == 0);
            }) begin
                `uvm_fatal("SEQ", "Narrow transfer randomization failed")
            end
            finish_item(req);
        end
    endtask
endclass


//==============================================================================//
// FIXED BURST SEQUENCE
//==============================================================================//
class fixed_burst_seq extends master_base_seq;
    `uvm_object_utils(fixed_burst_seq)

    function new(string name = "fixed_burst_seq");
        super.new(name);
    endfunction

    virtual task body();
        req = axi_txn::type_id::create("req");
        start_item(req);
        req.is_write = 1;

        if (!req.randomize() with {
            AWBURST == 2'b00;
            AWLEN < 16;
            AWADDR % 4 == 0;
        }) begin
            `uvm_fatal("SEQ", "Fixed burst randomization failed")
        end
        finish_item(req);
    endtask
endclass


//==============================================================================//
// WRAP BURST SEQUENCE
//==============================================================================//
class wrap_burst_seq extends master_base_seq;
    `uvm_object_utils(wrap_burst_seq)

    function new(string name = "wrap_burst_seq");
        super.new(name);
    endfunction

    virtual task body();
        req = axi_txn::type_id::create("req");
        start_item(req);
        req.is_write = 1;

        if (!req.randomize() with {
            AWBURST == 2'b10;
            AWLEN inside {1,3,7,15};
            AWADDR % 4 == 0;
        }) begin
            `uvm_fatal("SEQ", "Wrap burst randomization failed")
        end
        finish_item(req);
    endtask
endclass