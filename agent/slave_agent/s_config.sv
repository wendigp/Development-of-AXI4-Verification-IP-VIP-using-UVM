//=======================================================//
//SLAVE CONFIG
//======================================================//

class s_config extends uvm_object;

    `uvm_object_utils(s_config)

    //FLAGS
    virtual axi_if              vif;
    uvm_active_passive_enum     is_active = UVM_PASSIVE;
    
//***************************************************************************************//
//NOTE: Masters are typically ACTIVE and Slaves are very often PASSIVE by default
//Slave agent is often used only for monitoring
//**************************************************************************************//

    extern function new(string name = "s_config");
endclass

//CONSTRUCTOR
function s_config::new(string name = "s_config");
    super.new(name);
endfunction
