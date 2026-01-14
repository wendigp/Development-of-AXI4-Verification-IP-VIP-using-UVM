//==================================================================//
//VIRTUAL SEQUENCER
//=================================================================//

class v_sequencer extends uvm_sequencer #(uvm_sequence_item);

    `uvm_component_utils(v_sequencer)

    env_config  env_cfg;
    master_seqr      m_seqrh[];
    slave_seqr       s_seqrh[];

    extern function new(string name = "v_sequencer", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
endclass

//CONSTRUCTOR
function v_sequencer::new(string name = "v_sequencer", uvm_component parent);
    super.new(name,parent);
endfunction

//BUILD PHASE
function void v_sequencer::build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db #(env_config)::get(this,"","env_config",env_cfg))
        `uvm_fatal("VIRTUAL SEQUENCER","CANNOT GET DATA FROM ENV_CFG. HAVE YOU SET IT?")

    // Allocate handle arrays (no creation here)
    m_seqrh = new[env_cfg.no_of_masters];
    s_seqrh = new[env_cfg.no_of_slaves];

endfunction