//==============================================================================//
// MASTER SEQUENCER
// Implementation: 
//   - Standard UVM sequencer for AXI Transactions
//   - Facilitates communication between Sequences and Master Driver
//==============================================================================//

class master_seqr extends uvm_sequencer #(axi_txn);

    `uvm_component_utils(master_seqr)

    // Configuration handle (optional, if sequencer needs access to VIF or settings)
    m_config m_cfg;

    //-------------------------------------------------------------------------
    // CONSTRUCTOR
    //-------------------------------------------------------------------------
    function new(string name = "master_seqr", uvm_component parent);
        super.new(name, parent);
    endfunction

    //-------------------------------------------------------------------------
    // BUILD PHASE
    //-------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Retrieve master configuration if needed for sequence arbitration or knobs
        if(!uvm_config_db #(m_config)::get(this, "", "m_config", m_cfg)) begin
            `uvm_info("M_SEQR", "m_config not found in config_db (optional for sequencer)", UVM_HIGH)
        end
    endfunction

endclass