//==============================================================================//
// SLAVE SEQUENCER
// Implementation: 
//   - Standard UVM sequencer for AXI Transactions
//   - Facilitates communication between Slave Sequences and Slave Driver
//==============================================================================//

class slave_seqr extends uvm_sequencer #(axi_txn);

    `uvm_component_utils(slave_seqr)

    // Configuration handle for the slave agent
    s_config s_cfg;

    //-------------------------------------------------------------------------
    // CONSTRUCTOR
    //-------------------------------------------------------------------------
    function new(string name = "slave_seqr", uvm_component parent);
        super.new(name, parent);
    endfunction

    //-------------------------------------------------------------------------
    // BUILD PHASE
    //-------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Retrieve slave configuration
        if(!uvm_config_db #(s_config)::get(this, "", "s_config", s_cfg)) begin
            `uvm_info("S_SEQR", "s_config not found in config_db", UVM_HIGH)
        end
    endfunction

endclass