//===========================================//
//ENVIRONMENT CONFIG
//==========================================//

class env_config extends uvm_object;

    `uvm_object_utils(env_config)
    
    //FLAGS
    int unsigned no_of_masters = 1;
    int unsigned no_of_slaves = 1;
    bit has_scoreboard = 1;
    bit has_virtual_sequencer = 1;

    //MASTER/SLAVE CONFIG DECLARATION
    m_config        m_cfg[];
    s_config        s_cfg[];

    extern function new(string name = "env_config");
endclass

function env_config::new(string name = "env_config");
    super.new(name);
endfunction
