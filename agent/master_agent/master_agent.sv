//======================================================================//
//MASTER AGENT
//=====================================================================//

class m_agent extends uvm_agent;

    `uvm_component_utils(m_agent)

    m_config        m_cfg;
    m_driver        m_drv;
    m_monitor       m_mon;
    m_seqr          seqrh;

    extern function new(string name = "m_agent", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);
endclass

//CONSTRUCTOR
function m_agent::new(string name = "m_agent", uvm_component parent);
    super.new(name,parent);
endfunction

//BUILD PHASE
function void m_agent::build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db #(m_config)::get(this,"","m_config",m_cfg))
        `uvm_fatal("MASTER AGENT","CANNOT GET DATA FROM M_CFG. HAVE YOU SET IT?")
    
    //MONITOR OBJECT CREATION
    m_mon = m_monitor::type_id::create("m_mon",this);

    `uvm_info("MASTER_AGENT", $sformatf("Agent is %s", (is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE"), UVM_LOW)


    //SEQUENCER AND DRIVER CREATION BASED ON ACTIVE/PASSIVE AGENT
    if(is_active == UVM_ACTIVE)
        begin
            m_drv = m_driver::type_id::create("m_drv",this);

            seqrh = m_seqr::type_id::create("seqrh",this);
        end

    uvm_config_db #(virtual axi_if)::set(this,"m_drv","vif",m_cfg.vif);
    uvm_config_db #(virtual axi_if)::set(this,"m_mon","vif",m_cfg.vif);

endfunction

//CONNECT PHASE
function void m_agent::connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if(is_active == UVM_ACTIVE && m_drv != null && seqrh != null)
        begin
            m_drv.seq_item_port.connect(seqrh.seq_item_export);
        end
endfunction