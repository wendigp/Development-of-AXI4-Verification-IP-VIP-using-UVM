//==================================================================//
//VIRTUAL SEQUENCER
//=================================================================//

class v_seqr extends uvm_sequencer #(uvm_sequence_item);

    `uvm_component_utils(v_seqr)

    env_config  env_cfg;
    m_seqr      m_seqrh[];
    s_seqr      s_seqrh[];

    extern function new(string name = "v_seqr", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
endclass

//CONSTRUCTOR
function v_seqr::new(string name = "v_seqr", uvm_component parent);
    super.new(name,parent);
endclass

//BUILD PHASE
function void v_seqr::build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db #(env_config)::get(this,"","env_config",env_cfg))
        `uvm_fatal("VIRTUAL SEQUENCER","CANNOT GET DATA FROM ENV_CFG. HAVE YOU SET IT?")

    // Allocate handle arrays (no creation here)
    m_seqrh = new[env_cfg.no_of_masters];
    s_seqrh = new[env_cfg.no_of_slaves];

endfunction