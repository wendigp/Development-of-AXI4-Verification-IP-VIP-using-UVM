//===============================================================//
//MASTER DRIVER
//==============================================================//

class m_driver extends uvm_driver #(axi_txn);

    `uvm_component_utils(m_driver)

    m_config            m_cfg;
    virtual axi_if      vif;

    
    extern function new(string name = "m_driver", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);
    extern task run_phase(uvm_phase phase);
    extern task send_to_dut(axi_txn xtn);

    //TASK FOR WRITE OPERATION
    extern task write_addr(axi_txn xtn);
    extern task write_data(axi_txn xtn);
    extern task write_response(axi_txn xtn);
    
    //TASK FOR READ OPERATION
    extern task read_addr(axi_txn xtn);
    extern task read_data(axi_txn xtn);
endclass

//CONSTRUCTOR
function m_driver::new(string name = "m_driver", uvm_component parent);
    super.new(name,parent);
endfunction

//BUILD PHASE
function void m_driver::build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db #(m_config)::get(this,"","m_config",m_cfg))
        `uvm_fatal("MASTER DRIVER","CANNOT GET DATA FROM M_CFG. HAVE YOU SET IT?")
endfunction

//CONNECT PHASE
function void m_driver::connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    //Getting virual interface from m_config
        vif = m_cfg.vif;

    if(vif == null)
        `uvm_fatal("MASTER DRIVER", "VIF IS NULL")
endfunction

//RUN PHASE
task m_driver::run_phase(uvm_phase phase);

    //DEFAULT
    vif.drv_cb_m.RREADY <= 0;
    vif.drv_cb_m.BREADY <= 0;

    forever 
        begin
            seq_item_port.get_next_item(req);
            `uvm_info("MASTER DRIVER", "RECIEVED TRANSACTION", UVM_MEDIUM)
            send_to_dut(req);
            seq_item_port.item_done();
        end
endtask

//================================================================//
//SEND TO DUT
//===============================================================//
task m_driver::send_to_dut(axi_txn xtn);

    //WRITE TRANSACTION
    if(xtn.WDATA.size() != 0)
        begin
            `uvm_info(get_type_name(),"WRITE TRANSACTION STARTS",UVM_MEDIUM)
        fork
            write_addr(xtn);
            write_data(xtn);
        join
            write_response(xtn);
        
        `uvm_info(get_type_name(),"WRITE TRANSACTION ENDS",UVM_MEDIUM)
        end

    //READ TRANSACTION
    else
        begin
            `uvm_info(get_type_name(),"READ TRANSACTION STARTS",UVM_MEDIUM)

            read_addr(xtn);
            read_data(xtn);

            `uvm_info(get_type_name(),"READ TRANSACTION ENDS",UVM_MEDIUM)
        end
endtask

//***************************************************************************//
//WRITE ADDRESS CHANNEL
//**************************************************************************//
task m_driver::write_addr(axi_txn xtn);

        `uvm_info(get_type_name(),"START OF WRITE ADDRESS CHANNEL", UVM_HIGH)

        @(vif.drv_cb_m);
        vif.drv_cb_m.AWADDR  <= xtn.AWADDR;
        vif.drv_cb_m.AWID    <= xtn.AWID;
        vif.drv_cb_m.AWSIZE  <= xtn.AWSIZE;
        vif.drv_cb_m.AWBURST <= xtn.AWBURST;
        vif.drv_cb_m.AWLEN   <= xtn.AWLEN;
        vif.drv_cb_m.AWVALID <= 1;

        do begin
            @(vif.drv_cb_m);
            end
        while(vif.drv_cb_m.AWREADY !== 1);
          //  @(vif.drv_cb_m);

        vif.drv_cb_m.AWVALID <= 0;
        vif.drv_cb_m.AWADDR  <= 'bx;
        vif.drv_cb_m.AWID    <= 4'bx;
        vif.drv_cb_m.AWSIZE  <= 3'bx;
        vif.drv_cb_m.AWBURST <= 2'bx;
        vif.drv_cb_m.AWLEN   <= 8'bx;

        repeat($urandom_range(1,5))@(vif.drv_cb_m);
        `uvm_info(get_type_name(),"END OF WRITE ADDRESS CHANNEL",UVM_HIGH)
    
endtask

//***********************************************************************************//
//WRITE DATA CHANNEL
//**********************************************************************************//
task m_driver::write_data(axi_txn xtn);

    `uvm_info(get_type_name(),"START OF WRITE DATA CHANNEL", UVM_HIGH)

            for(int i = 0; i < xtn.AWLEN + 1; i++)
                begin
                @(vif.drv_cb_m);
                vif.drv_cb_m.WVALID     <= 1;
                vif.drv_cb_m.WDATA      <= xtn.WDATA[i];
                vif.drv_cb_m.WSTRB      <= xtn.WSTRB[i];

                if(i == xtn.AWLEN)
                    vif.drv_cb_m.WLAST  <= 1;
                else
                    vif.drv_cb_m.WLAST  <= 0;

                do begin
                    @(vif.drv_cb_m);
                    end
                while(vif.drv_cb_m.WREADY  !== 1);
                   // @(vif.drv_cb_m);
                
                vif.drv_cb_m.WVALID     <= 0;
                vif.drv_cb_m.WLAST      <= 0;
                vif.drv_cb_m.WDATA      <= 'bx;
                vif.drv_cb_m.WSTRB      <= 'bx; 

                repeat($urandom_range(1,5)) @(vif.drv_cb_m);
        end
        `uvm_info(get_type_name(),"END OF WRITE DATA CHANNEL", UVM_HIGH)
endtask

//****************************************************************************************//
//WRITE RESPONSE CHANNEL
//***************************************************************************************//
task m_driver::write_response(axi_txn xtn);

    `uvm_info(get_type_name(), "START OF WRITE RESPONSE CHANNEL", UVM_HIGH)

    do begin 
        @(vif.drv_cb_m);
        end
    while(vif.drv_cb_m.BVALID !== 1);
     //   @(vif.drv_cb_m);

    repeat($urandom_range(0,5)) @(vif.drv_cb_m);
    vif.drv_cb_m.BREADY     <= 1;
    @(vif.drv_cb_m);
    vif.drv_cb_m.BREADY     <= 0;

    `uvm_info(get_type_name(), "END OF WRITE RESPONSE CHANNEL",UVM_HIGH)
endtask

//********************************************************************************************//
//READ ADDRESS CHANNEL
//*******************************************************************************************//
task m_driver::read_addr(axi_txn xtn);

    `uvm_info(get_type_name(),"START OF READ ADDRESS CHANNEL",UVM_HIGH)

    @(vif.drv_cb_m);
    vif.drv_cb_m.ARVALID        <= 1;
    vif.drv_cb_m.ARADDR         <= xtn.ARADDR;
    vif.drv_cb_m.ARID           <= xtn.ARID;
    vif.drv_cb_m.ARLEN          <= xtn.ARLEN;
    vif.drv_cb_m.ARSIZE         <= xtn.ARSIZE;
    vif.drv_cb_m.ARBURST        <= xtn.ARBURST;

    do begin 
        @(vif.drv_cb_m);
        end
    while(vif.drv_cb_m.ARREADY !== 1);
    //    @(vif.drv_cb_m);
    
    vif.drv_cb_m.ARVALID        <= 0;
    vif.drv_cb_m.ARID           <= 4'bx;
    vif.drv_cb_m.ARADDR         <= 'bx;
    vif.drv_cb_m.ARLEN          <= 8'bx;
    vif.drv_cb_m.ARSIZE         <= 3'bx;
    vif.drv_cb_m.ARBURST        <= 2'bx;

    repeat($urandom_range(1,5)) @(vif.drv_cb_m);

    `uvm_info(get_type_name(), "END OF READ ADDRESS CHANNEL")
endtask

//******************************************************************************************//
//READ DATA CHANNEL
//*****************************************************************************************//
task m_driver::read_data(axi_txn xtn);

    `uvm_info(get_type_name(),"START OF READ DATA",UVM_HIGH)

    for(int i = 0; i <= xtn.ARLEN; i++) begin
        // AXI Master must be able to pull RREADY low (backpressure)
        // For a basic driver, we stay ready:
        vif.drv_cb_m.RREADY <= 1'b1;

        do begin
            @(vif.drv_cb_m);
        end while (vif.drv_cb_m.RVALID !== 1'b1);

        // Capture data if needed for the sequence
        // xtn.RDATA[i] = vif.drv_cb_m.RDATA; 

        if(vif.drv_cb_m.RRESP > 2'b00)
            `uvm_warning("AXI_RESP", "Non-OKAY response detected")

        if(i == xtn.ARLEN && vif.drv_cb_m.RLAST !== 1'b1)
            `uvm_error("AXI_LAST", "RLAST missing on last beat!")
        
        vif.drv_cb_m.RREADY <= 1'b0; // De-assert after each beat or end of burst
        repeat($urandom_range(0,2)) @(vif.drv_cb_m); // Insertion of "Master Delay"
    end
        `uvm_info(get_type_name(),"END OF READ DATA",UVM_HIGH);
endtask
