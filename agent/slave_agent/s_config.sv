//=======================================================//
//SLAVE CONFIG
//======================================================//

class s_config extends uvm_object;

    `uvm_object_utils(s_config)

    //FLAGS
    virtual axi_if              vif;
    uvm_active_passive_enum     is_active = UVM_PASSIVE;
    
    extern function new(string name = "s_config");
endclass

//CONSTRUCTOR
function s_config::new(string name = "s_config");
    super.new(name);
endfunction
