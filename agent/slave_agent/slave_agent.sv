//======================================================================//
//SLAVE AGENT
//=====================================================================//

class slave_agent extends uvm_agent;

    `uvm_component_utils(slave_agent)

    s_config        s_cfg;
    s_driver        s_drv;
    s_monitor       monh;
    slave_seqr      seqrh;

    extern function new(string name = "slave_agent", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);
endclass

//CONSTRUCTOR
function slave_agent::new(string name = "slave_agent", uvm_component parent);
    super.new(name,parent);
endfunction

//BUILD PHASE
function void slave_agent::build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db #(s_config)::get(this,"","s_config",s_cfg))
        `uvm_fatal("SLAVE AGENT","CANNOT GET DATA FROM S_CFG. HAVE YOU SET IT?")
    
    //MONITOR OBJECT CREATION
    monh = s_monitor::type_id::create("monh",this);

    `uvm_info("SLAVE_AGENT", $sformatf("Agent is %s", (is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE"), UVM_LOW)


    //SEQUENCER AND DRIVER CREATION BASED ON ACTIVE/PASSIVE AGENT
    if(is_active == UVM_ACTIVE)
        begin
            s_drv = s_driver::type_id::create("s_drv",this);

            seqrh = slave_seqr::type_id::create("seqrh",this);
        end

    uvm_config_db #(virtual axi_if)::set(this,"s_drv","vif",s_cfg.vif);
    uvm_config_db #(virtual axi_if)::set(this,"monh","vif",s_cfg.vif);

endfunction

//CONNECT PHASE
function void slave_agent::connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if(is_active == UVM_ACTIVE && s_drv != null && seqrh != null)
        begin
            s_drv.seq_item_port.connect(seqrh.seq_item_export);
        end
endfunction