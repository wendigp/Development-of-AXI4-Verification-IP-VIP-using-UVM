//======================================================================//
//SLAVE AGENT
//=====================================================================//

class s_agent extends uvm_agent;

    `uvm_component_utils(s_agent)

    s_config        s_cfg;
    s_driver        s_drv;
    s_monitor       s_mon;
    s_seqr          seqrh;

    extern function new(string name = "s_agent", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);
endclass

//CONSTRUCTOR
function s_agent::new(string name = "s_agent", uvm_component parent);
    super.new(name,parent);
endfunction

//BUILD PHASE
function void s_agent::build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db #(s_config)::get(this,"","s_config",s_cfg))
        `uvm_fatal("SLAVE AGENT","CANNOT GET DATA FROM S_CFG. HAVE YOU SET IT?")
    
    //MONITOR OBJECT CREATION
    s_mon = s_monitor::type_id::create("s_mon",this);

    `uvm_info("SLAVE_AGENT", $sformatf("Agent is %s", (is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE"), UVM_LOW)


    //SEQUENCER AND DRIVER CREATION BASED ON ACTIVE/PASSIVE AGENT
    if(is_active == UVM_ACTIVE)
        begin
            s_drv = s_driver::type_id::create("s_drv",this);

            seqrh = s_seqr::type_id::create("seqrh",this);
        end

    uvm_config_db #(virtual axi_if)::set(this,"s_drv","vif",s_cfg.vif);
    uvm_config_db #(virtual axi_if)::set(this,"s_mon","vif",s_cfg.vif);

endfunction

//CONNECT PHASE
function void s_agent::connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if(is_active == UVM_ACTIVE && s_drv != null && seqrh != null)
        begin
            s_drv.seq_item_port.connect(seqrh.seq_item_export);
        end
endfunction