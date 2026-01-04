//==============================================================================
// AXI TRANSACTION
//==============================================================================

class axi_txn #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int LEN_WIDTH  = 8
) extends uvm_sequence_item;

    `uvm_object_utils(axi_txn)

    // Internal helper arrays for address tracking
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
    rand bit [DATA_WIDTH-1:0]      WDATA[];
    rand bit [(DATA_WIDTH/8)-1:0]  WSTRB[];
         bit                       WLAST;

    //--------------------------------------------------------------------------
    // WRITE RESPONSE CHANNEL
    //--------------------------------------------------------------------------
    bit [ID_WIDTH-1:0] BID;
    bit [1:0]          BRESP;
    rand bit           BREADY;

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
    bit [DATA_WIDTH-1:0] RDATA[];
    bit [ID_WIDTH-1:0]   RID;
    bit [1:0]            RRESP;
    bit                  RLAST;
    rand bit             RREADY;

    //--------------------------------------------------------------------------
    // CONSTRAINTS
    //--------------------------------------------------------------------------
    constraint c_burst_type {
        AWBURST inside {2'b00, 2'b01, 2'b10};
        ARBURST inside {2'b00, 2'b01, 2'b10};
    }

    constraint c_size {
        AWSIZE == $clog2(DATA_WIDTH/8);
        ARSIZE == $clog2(DATA_WIDTH/8);
    }

    constraint w_len {
        if (AWBURST == 2'b10) AWLEN inside {1, 3, 7, 15};
        else                  AWLEN inside {[0 : (2**LEN_WIDTH)-1]};
    }

    constraint r_len {
        if (ARBURST == 2'b10) ARLEN inside {1, 3, 7, 15};
        else                  ARLEN inside {[0 : (2**LEN_WIDTH)-1]};
    }

    constraint aligned_address {
        AWADDR % (2**AWSIZE) == 0;
        ARADDR % (2**ARSIZE) == 0;
    }

    constraint c_wdata_size {
        WDATA.size() == AWLEN + 1;
        WSTRB.size() == AWLEN + 1;
    }

    //--------------------------------------------------------------------------
    // METHODS
    //--------------------------------------------------------------------------
    extern function new(string name = "axi_txn");
    extern function void do_print(uvm_printer printer);
    extern function void do_copy(uvm_object rhs);
    extern function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    extern function void post_randomize();
    extern function void w_addr_calc();
    extern function void r_addr_calc();
    extern function void strb_calc();

endclass

//--------------------------------------------------------------------------
// CONSTRUCTOR
//--------------------------------------------------------------------------
function axi_txn::new(string name = "axi_txn");
    super.new(name);
endfunction

//--------------------------------------------------------------------------
// PRINT (CLASSIFIED BY CHANNEL)
//--------------------------------------------------------------------------
function void axi_txn::do_print(uvm_printer printer);
    super.do_print(printer);

    //================ WRITE ADDRESS CHANNEL (AW) ================
    printer.print_string("CHANNEL", "WRITE_ADDRESS");
    printer.print_field("AWADDR",  AWADDR,  ADDR_WIDTH, UVM_HEX);
    printer.print_field("AWID",    AWID,    ID_WIDTH,   UVM_DEC);
    printer.print_field("AWLEN",   AWLEN,   LEN_WIDTH,  UVM_DEC);
    printer.print_field("AWSIZE",  AWSIZE,  3,          UVM_DEC);
    printer.print_field("AWBURST", AWBURST, 2,          UVM_BIN);

    //================ WRITE DATA CHANNEL (W) ====================
    printer.print_string("CHANNEL", "WRITE_DATA");
    foreach(WDATA[i]) printer.print_field($sformatf("WDATA[%0d]",i), WDATA[i], DATA_WIDTH, UVM_HEX);
    foreach(WSTRB[i]) printer.print_field($sformatf("WSTRB[%0d]",i), WSTRB[i], DATA_WIDTH/8, UVM_BIN);
    printer.print_field("WLAST",   WLAST,   1,          UVM_BIN);

    //================ WRITE RESPONSE CHANNEL (B) ================
    printer.print_string("CHANNEL", "WRITE_RESPONSE");
    printer.print_field("BID",     BID,     ID_WIDTH,   UVM_DEC);
    printer.print_field("BRESP",   BRESP,   2,          UVM_BIN);
    printer.print_field("BREADY",  BREADY,  1,          UVM_BIN);

    //================ READ ADDRESS CHANNEL (AR) =================
    printer.print_string("CHANNEL", "READ_ADDRESS");
    printer.print_field("ARADDR",  ARADDR,  ADDR_WIDTH, UVM_HEX);
    printer.print_field("ARID",    ARID,    ID_WIDTH,   UVM_DEC);
    printer.print_field("ARLEN",   ARLEN,   LEN_WIDTH,  UVM_DEC);
    printer.print_field("ARSIZE",  ARSIZE,  3,          UVM_DEC);
    printer.print_field("ARBURST", ARBURST, 2,          UVM_BIN);

    //================ READ DATA CHANNEL (R) =====================
    printer.print_string("CHANNEL", "READ_DATA");
    foreach(RDATA[i]) printer.print_field($sformatf("RDATA[%0d]",i), RDATA[i], DATA_WIDTH, UVM_HEX);
    printer.print_field("RID",     RID,     ID_WIDTH,   UVM_DEC);
    printer.print_field("RRESP",   RRESP,   2,          UVM_BIN);
    printer.print_field("RLAST",   RLAST,   1,          UVM_BIN);
    printer.print_field("RREADY",  RREADY,  1,          UVM_BIN);
endfunction

//--------------------------------------------------------------------------
// COPY (CLASSIFIED BY CHANNEL)
//--------------------------------------------------------------------------
function void axi_txn::do_copy(uvm_object rhs);

    axi_txn #(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH, LEN_WIDTH) rhs_;
    if (!$cast(rhs_, rhs)) 
    `uvm_fatal("AXI_TXN", "do_copy cast failed")
    
    super.do_copy(rhs);

    // ---------------- WRITE ADDRESS CHANNEL ----------------
    this.AWADDR  = rhs_.AWADDR;
    this.AWID    = rhs_.AWID;
    this.AWLEN   = rhs_.AWLEN;
    this.AWSIZE  = rhs_.AWSIZE;
    this.AWBURST = rhs_.AWBURST;

    // ---------------- WRITE DATA CHANNEL -------------------
    this.WDATA   = rhs_.WDATA;
    this.WSTRB   = rhs_.WSTRB;
    this.WLAST   = rhs_.WLAST;

    // ---------------- WRITE RESPONSE CHANNEL ---------------
    this.BID     = rhs_.BID;
    this.BRESP   = rhs_.BRESP;
    this.BREADY  = rhs_.BREADY;

    // ---------------- READ ADDRESS CHANNEL -----------------
    this.ARADDR  = rhs_.ARADDR;
    this.ARID    = rhs_.ARID;
    this.ARLEN   = rhs_.ARLEN;
    this.ARSIZE  = rhs_.ARSIZE;
    this.ARBURST = rhs_.ARBURST;

    // ---------------- READ DATA CHANNEL --------------------
    this.RDATA   = rhs_.RDATA;
    this.RID     = rhs_.RID;
    this.RRESP   = rhs_.RRESP;
    this.RLAST   = rhs_.RLAST;
    this.RREADY  = rhs_.RREADY;
endfunction

//--------------------------------------------------------------------------
// COMPARE
//--------------------------------------------------------------------------
function bit axi_txn::do_compare(uvm_object rhs, uvm_comparer comparer);
    
axi_txn #(ADDR_WIDTH, DATA_WIDTH, ID_WIDTH, LEN_WIDTH) xtn;
    
if (!$cast(xtn, rhs))
       return 0;
    
    return (super.do_compare(rhs, comparer) &&
            (this.AWADDR == xtn.AWADDR) &&
            (this.WDATA  == xtn.WDATA)  &&
            (this.WSTRB  == xtn.WSTRB)  &&
            (this.ARADDR == xtn.ARADDR) &&
            (this.RDATA  == xtn.RDATA));
endfunction

function void axi_txn::post_randomize();
    w_addr_calc();
    r_addr_calc();
    strb_calc();
endfunction

//--------------------------------------------------------------------------
// ADDRESS CALCULATION 
//--------------------------------------------------------------------------
function void axi_txn::w_addr_calc();
    int unsigned num_bytes = 2**AWSIZE;
    int unsigned burst_len = AWLEN + 1;
    
    waddr = new[burst_len];
    waddr[0] = AWADDR;

    case (AWBURST)
        2'b00: begin // FIXED
            for (int i = 1; i < burst_len; i++) waddr[i] = waddr[0];
        end
        2'b01: begin // INCR
            for (int i = 1; i < burst_len; i++) waddr[i] = waddr[i-1] + num_bytes;
        end
        2'b10: begin // WRAP
            int unsigned wrap_size = num_bytes * burst_len;
            int unsigned wrap_boundary = (AWADDR / wrap_size) * wrap_size;
            for (int i = 1; i < burst_len; i++) begin
                waddr[i] = waddr[i-1] + num_bytes;
                if (waddr[i] >= wrap_boundary + wrap_size) waddr[i] = wrap_boundary;
            end
        end
    endcase
endfunction

function void axi_txn::r_addr_calc();
    int unsigned num_bytes = 2**ARSIZE;
    int unsigned burst_len = ARLEN + 1;
    
    raddr = new[burst_len];
    raddr[0] = ARADDR;

    case (ARBURST)
        2'b00: begin // FIXED
            for (int i = 1; i < burst_len; i++) raddr[i] = raddr[0];
        end
        2'b01: begin // INCR
            for (int i = 1; i < burst_len; i++) raddr[i] = raddr[i-1] + num_bytes;
        end
        2'b10: begin // WRAP
            int unsigned wrap_size = num_bytes * burst_len;
            int unsigned wrap_boundary = (ARADDR / wrap_size) * wrap_size;
            for (int i = 1; i < burst_len; i++) begin
                raddr[i] = raddr[i-1] + num_bytes;
                if (raddr[i] >= wrap_boundary + wrap_size) raddr[i] = wrap_boundary;
            end
        end
    endcase
endfunction



//--------------------------------------------------------------------------
// STROBE CALCULATION
//--------------------------------------------------------------------------
function void axi_txn::strb_calc();
    int unsigned num_bytes = 2**AWSIZE;
    int unsigned bus_bytes = DATA_WIDTH/8;

    foreach (WSTRB[i]) begin
        WSTRB[i] = 0; 
        for (int lane = 0; lane < bus_bytes; lane++) begin
            if ((lane >= (waddr[i] % bus_bytes)) && 
                (lane <  (waddr[i] % bus_bytes) + num_bytes)) begin
                WSTRB[i][lane] = 1;
            end
        end
    end
endfunction