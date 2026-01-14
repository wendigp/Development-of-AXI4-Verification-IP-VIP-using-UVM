
//==============================================================================//
// VIRTUAL BASE SEQUENCE
// Fixes: 
//   - Removed uvm_sequence_item parameterization (uses default)
//   - Replaced manual casting with `uvm_declare_p_sequencer
//   - Fixed config_db lookup to use m_sequencer scope
//==============================================================================//
class v_base_seq extends uvm_sequence;
    `uvm_object_utils(v_base_seq)
    
    // Macro to automate casting of m_sequencer to p_sequencer (v_sequencer)
    `uvm_declare_p_sequencer(v_sequencer)

    // Handles for physical sequencers (routed from virtual sequencer)
    master_seqr         m_seqr;
    slave_seqr          s_seqr;
    env_config          env_cfg;

    // Handles for all available Master sub-sequences
    incr_burst_seq          incr_s;
    raw_hazard_seq          raw_s;
    narrow_transfer_seq     narrow_s;
    fixed_burst_seq         fixed_s;
    wrap_burst_seq          wrap_s;

    extern function new(string name = "v_base_seq");
    extern virtual task body();
endclass

function v_base_seq::new(string name = "v_base_seq");
    super.new(name);
endfunction

task v_base_seq::body();
    // 1. Correct Config Lookup: Use m_sequencer (the parent component) to get config
    // Virtual sequences are objects, not components; they must lookup relative to their sequencer.
    if(!uvm_config_db #(env_config)::get(m_sequencer, "", "env_config", env_cfg)) begin
        `uvm_fatal("VIRTUAL_SEQ", "CANNOT GET env_config from m_sequencer scope")
    end

    // 2. Extract physical sequencer handles from p_sequencer (set up by macro)
    m_seqr = p_sequencer.m_seqrh[0];
    s_seqr = p_sequencer.s_seqrh[0];
endtask

//==============================================================================//
// VIRTUAL TEST CASE 1: INCREMENTAL BURSTS
//==============================================================================//
class v_incr_burst_test_seq extends v_base_seq;
    `uvm_object_utils(v_incr_burst_test_seq)

    extern function new(string name = "v_incr_burst_test_seq");
    extern virtual task body();
endclass

function v_incr_burst_test_seq::new(string name = "v_incr_burst_test_seq");
    super.new(name);
endfunction

task v_incr_burst_test_seq::body();
    super.body();
    incr_s = incr_burst_seq::type_id::create("incr_s");
    incr_s.start(m_seqr);
endtask

//==============================================================================//
// VIRTUAL TEST CASE 2: READ-AFTER-WRITE HAZARDS
//==============================================================================//
class v_raw_hazard_test_seq extends v_base_seq;
    `uvm_object_utils(v_raw_hazard_test_seq)

    extern function new(string name = "v_raw_hazard_test_seq");
    extern virtual task body();
endclass

function v_raw_hazard_test_seq::new(string name = "v_raw_hazard_test_seq");
    super.new(name);
endfunction

task v_raw_hazard_test_seq::body();
    super.body();
    raw_s = raw_hazard_seq::type_id::create("raw_s");
    repeat(10) begin
        raw_s.start(m_seqr);
    end
endtask

//==============================================================================//
// VIRTUAL TEST CASE 3: BURST VARIATIONS (FIXED/WRAP)
//==============================================================================//
class v_burst_variation_test_seq extends v_base_seq;
    `uvm_object_utils(v_burst_variation_test_seq)

    extern function new(string name = "v_burst_variation_test_seq");
    extern virtual task body();
endclass

function v_burst_variation_test_seq::new(string name = "v_burst_variation_test_seq");
    super.new(name);
endfunction

task v_burst_variation_test_seq::body();
    super.body();
    fixed_s = fixed_burst_seq::type_id::create("fixed_s");
    wrap_s  = wrap_burst_seq::type_id::create("wrap_s");
    
    fork
        fixed_s.start(m_seqr);
        wrap_s.start(m_seqr);
    join
endtask