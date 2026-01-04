
//==============================================//
//MASTER UVC == MASTER AGENT TOP
//==============================================//

class master_uvc extends uvm_component;

    `uvm_component_utils(master_uvc)

    env_config      env_cfg;
    master_agent    m_agent[];

    extern function new(string name = "master_uvc", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
endclass

//CONSTRUCTOR
function master_uvc::new(string name = "master_uvc", uvm_component parent);
    super.new(name,parent);
endfunction

//BUILD PHASE
function void master_uvc::build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db #(env_config)::get(this,"","env_config",env_cfg))
        `uvm_fatal("MASTER UVC", "CANNOT GET DATA FROM ENV_CONFIG. HAVE YOU SET IT?")
    
    m_agent = new[env_cfg.no_of_masters];

    foreach(m_agent[i])
        begin
            m_agent[i] = master_agent::type_id::create($sformatf("m_agent[%0d]",i),this);

            uvm_config_db#(uvm_active_passive_enum)::set(this, $sformatf("m_agent[%0d]*", i), "is_active", env_cfg.m_cfg[i].is_active);
            //SETTING DATA TO MASTER CONFIG
            uvm_config_db #(m_config)::set(this,$sformatf("m_agent[%0d]*",i),"m_config", env_cfg.m_cfg[i]);
        end
endfunction


