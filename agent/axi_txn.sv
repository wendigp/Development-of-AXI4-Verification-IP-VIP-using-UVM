//==============================================================================
// AXI TRANSACTION (FIXED)
// Uses centralized definitions from axi_defs
//==============================================================================

class axi_txn extends uvm_sequence_item;

    `uvm_object_utils(axi_txn)

    //--------------------------------------------------------------------------
    // META / ROUTING
    //--------------------------------------------------------------------------
    bit is_write;   // 1 = WRITE transaction, 0 = READ transaction

    //--------------------------------------------------------------------------
    // Internal helper arrays for address tracking
    //--------------------------------------------------------------------------
    int unsigned raddr[];
    int unsigned waddr[];

    //--------------------------------------------------------------------------
    // WRITE ADDRESS CHANNEL
    //--------------------------------------------------------------------------
    rand bit [ADDR_WIDTH-1:0] AWADDR;
    rand bit [ID_WIDTH-1:0]   AWID;
    rand bit [LEN_WIDTH-1:0]  AWLEN;
    rand bit [2:0]            AWSIZE;
    rand bit [1:0]            AWBURST;

    //--------------------------------------------------------------------------
    // WRITE DATA CHANNEL
    //--------------------------------------------------------------------------
    bit [DATA_WIDTH-1:0]        WDATA[$];   // burst beats
    bit [(DATA_WIDTH/8)-1:0]    WSTRB[$];   // per-beat strobes
    bit                         WLAST;

    //--------------------------------------------------------------------------
    // WRITE RESPONSE CHANNEL
    //--------------------------------------------------------------------------
    bit  [ID_WIDTH-1:0] BID;
    bit  [1:0]          BRESP;
    rand bit            BREADY;

    //--------------------------------------------------------------------------
    // READ ADDRESS CHANNEL
    //--------------------------------------------------------------------------
    rand bit [ADDR_WIDTH-1:0] ARADDR;
    rand bit [ID_WIDTH-1:0]   ARID;
    rand bit [LEN_WIDTH-1:0]  ARLEN;
    rand bit [2:0]            ARSIZE;
    rand bit [1:0]            ARBURST;

    //--------------------------------------------------------------------------
    // READ DATA CHANNEL
    //--------------------------------------------------------------------------
    bit  [DATA_WIDTH-1:0] RDATA[$];  // burst beats
    bit  [ID_WIDTH-1:0]   RID;
    bit  [1:0]            RRESP;
    bit                   RLAST;
    rand bit              RREADY;

    //--------------------------------------------------------------------------
    // CONSTRAINTS
    //--------------------------------------------------------------------------

    constraint c_burst_type {
        AWBURST inside {FIXED, INCR, WRAP};
        ARBURST inside {FIXED, INCR, WRAP};
    }

    constraint c_size {
        AWSIZE == $clog2(DATA_WIDTH/8);
        ARSIZE == $clog2(DATA_WIDTH/8);
    }

    constraint c_w_len {
        if (AWBURST == WRAP)
            AWLEN inside {1, 3, 7, 15};
        else
            AWLEN inside {[0:(2**LEN_WIDTH)-1]};
    }

    constraint c_r_len {
        if (ARBURST == WRAP)
            ARLEN inside {1, 3, 7, 15};
        else
            ARLEN inside {[0:(2**LEN_WIDTH)-1]};
    }

    constraint c_addr_align {
        AWADDR % (2**AWSIZE) == 0;
        ARADDR % (2**ARSIZE) == 0;
    }

    // REMOVED: constraint c_wdata_size - queues are populated in post_randomize

    //--------------------------------------------------------------------------
    // METHODS
    //--------------------------------------------------------------------------

    function new(string name = "axi_txn");
        super.new(name);
    endfunction

    function void post_randomize();
        w_addr_calc();
        r_addr_calc();
        strb_calc();
        
        // FIX: Populate WDATA array with random data
        WDATA.delete();
        for (int i = 0; i <= AWLEN; i++) begin
            WDATA.push_back($urandom());
        end
        
        `uvm_info("AXI_TXN", $sformatf("Transaction created: is_write=%0d, AWLEN=%0d, WDATA.size=%0d", 
                  is_write, AWLEN, WDATA.size()), UVM_HIGH)
    endfunction

    //--------------------------------------------------------------------------
    // ADDRESS CALCULATION
    //--------------------------------------------------------------------------

    function void w_addr_calc();
        int unsigned num_bytes = 2**AWSIZE;
        int unsigned burst_len = AWLEN + 1;

        waddr = new[burst_len];
        waddr[0] = AWADDR;

        case (AWBURST)
            FIXED: for (int i = 1; i < burst_len; i++)
                       waddr[i] = waddr[0];

            INCR : for (int i = 1; i < burst_len; i++)
                       waddr[i] = waddr[i-1] + num_bytes;

            WRAP : begin
                int unsigned wrap_size = num_bytes * burst_len;
                int unsigned base = (AWADDR / wrap_size) * wrap_size;
                for (int i = 1; i < burst_len; i++) begin
                    waddr[i] = waddr[i-1] + num_bytes;
                    if (waddr[i] >= base + wrap_size)
                        waddr[i] = base;
                end
            end
        endcase
    endfunction

    function void r_addr_calc();
        int unsigned num_bytes = 2**ARSIZE;
        int unsigned burst_len = ARLEN + 1;

        raddr = new[burst_len];
        raddr[0] = ARADDR;

        case (ARBURST)
            FIXED: for (int i = 1; i < burst_len; i++)
                       raddr[i] = raddr[0];

            INCR : for (int i = 1; i < burst_len; i++)
                       raddr[i] = raddr[i-1] + num_bytes;

            WRAP : begin
                int unsigned wrap_size = num_bytes * burst_len;
                int unsigned base = (ARADDR / wrap_size) * wrap_size;
                for (int i = 1; i < burst_len; i++) begin
                    raddr[i] = raddr[i-1] + num_bytes;
                    if (raddr[i] >= base + wrap_size)
                        raddr[i] = base;
                end
            end
        endcase
    endfunction

    //--------------------------------------------------------------------------
    // STROBE CALCULATION
    //--------------------------------------------------------------------------

    function void strb_calc();
        int unsigned bus_bytes = DATA_WIDTH / 8;
        int unsigned num_bytes = 2**AWSIZE;

        WSTRB.delete();
        
        for (int i = 0; i <= AWLEN; i++) begin
            bit [(DATA_WIDTH/8)-1:0] strb = '0;
            
            for (int lane = 0; lane < bus_bytes; lane++) begin
                if (lane >= (waddr[i] % bus_bytes) &&
                    lane <  (waddr[i] % bus_bytes) + num_bytes)
                    strb[lane] = 1'b1;
            end
            
            WSTRB.push_back(strb);
        end
    endfunction

endclass