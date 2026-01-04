//==============================================//
//SLAVE UVC == SLAVE AGENT TOP
//==============================================//

class slave_uvc extends uvm_component;

    `uvm_component_utils(slave_uvc)

    env_config      env_cfg;
    slave_agent    s_agent[];

    extern function new(string name = "slave_uvc", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
endclass

//CONSTRUCTOR
function slave_uvc::new(string name = "slave_uvc", uvm_component parent);
    super.new(name,parent);
endfunction

//BUILD PHASE
function void slave_uvc::build_phase(uvm_phase phase);
        super.build_phase(phase);

    if(!uvm_config_db #(env_config)::get(this,"","env_config",env_cfg))
        `uvm_fatal("SLAVE UVC", "CANNOT GET DATA FROM ENV_CONFIG. HAVE YOU SET IT?")

    s_agent = new[env_cfg.no_of_slaves];

    foreach(s_agent[i])
        begin
        s_agent[i] = slave_agent::type_id::create($sformatf("s_agent[%0d]",i),this);

        uvm_config_db#(uvm_active_passive_enum)::set(this, $sformatf("s_agent[%0d]*", i), "is_active", env_cfg.s_cfg[i].is_active);
        //SETTING DATA TO SLAVE CONFIG
        uvm_config_db #(s_config)::set(this,$sformatf("s_agent[%0d]*",i),"s_config", env_cfg.s_cfg[i]);
        end
endfunction


