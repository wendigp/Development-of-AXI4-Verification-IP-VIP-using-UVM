//==============================================================================//
// AXI VIP PACKAGE
//==============================================================================//

package axi_pkg;

    //--------------------------------------------------------------------------//
    // UVM
    //--------------------------------------------------------------------------//
    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import axi_defs::*;

    //--------------------------------------------------------------------------//
    // 1. TRANSACTION & CONFIGURATION OBJECTS
    //--------------------------------------------------------------------------//
    `include "agent/axi_txn.sv"

    `include "agent/master_agent/m_config.sv"
    `include "agent/slave_agent/s_config.sv"
    `include "env/env_config.sv"

    //--------------------------------------------------------------------------//
    // 2. MASTER AGENT
    //--------------------------------------------------------------------------//
    `include "agent/master_agent/m_seqr.sv"
    `include "agent/master_agent/m_driver.sv"
    `include "agent/master_agent/m_monitor.sv"
    `include "agent/master_agent/master_seq.sv"
    `include "agent/master_agent/master_agent.sv"
    `include "agent/m_uvc.sv"

    //--------------------------------------------------------------------------//
    // 3. SLAVE AGENT
    //--------------------------------------------------------------------------//
    `include "agent/slave_agent/s_seqr.sv"
    `include "agent/slave_agent/s_driver.sv"
    `include "agent/slave_agent/s_monitor.sv"
    `include "agent/slave_agent/slave_agent.sv"
    `include "agent/s_uvc.sv"

    //--------------------------------------------------------------------------//
    // 4. ANALYSIS COMPONENTS
    //--------------------------------------------------------------------------//
    `include "agent/subscriber.sv"
    `include "env/scoreboard.sv"

    //--------------------------------------------------------------------------//
    // 5. VIRTUAL SEQUENCER & ENVIRONMENT (CLASSES ONLY)
    //--------------------------------------------------------------------------//
    `include "v_seqr/v_seqr.sv"
    `include "env/env.sv"

    //--------------------------------------------------------------------------//
    // 6. VIRTUAL SEQUENCES
    //--------------------------------------------------------------------------//
    `include "v_seqr/v_seq.sv"

    //--------------------------------------------------------------------------//
    // 7. TESTS
    //--------------------------------------------------------------------------//
    `include "tests/axi_test.sv"

endpackage : axi_pkg
