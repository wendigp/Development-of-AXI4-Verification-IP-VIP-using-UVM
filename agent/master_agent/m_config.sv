//=======================================================//
//MASTER CONFIG
//======================================================//

class m_config extends uvm_object;

    `uvm_object_utils(m_config)

    //FLAGS
    virtual axi_if              vif;
    uvm_active_passive_enum     is_active = UVM_ACTIVE;

    extern function new(string name = "m_config");
endclass

//CONSTRUCTOR
function m_config::new(string name = "m_config");
    super.new(name);
endfunction
