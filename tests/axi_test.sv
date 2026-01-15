//==============================================================================//
// AXI TOP LEVEL TESTS
//==============================================================================//

//-----------------------------------------------------------------------------
// BASE TEST
//-----------------------------------------------------------------------------
class base_test extends uvm_test;
    `uvm_component_utils(base_test)

    env             env_h;
    env_config      env_cfg;
    m_config        m_cfg_h[];
    s_config        s_cfg_h[];

    extern function new(string name = "base_test", uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void end_of_elaboration_phase(uvm_phase phase);
endclass

//Constructor
function base_test::new(string name = "base_test", uvm_component parent);
    super.new(name, parent);
endfunction

// Build Phase
function void base_test::build_phase(uvm_phase phase);
    super.build_phase(phase);

    env_cfg = env_config::type_id::create("env_cfg");
    
    env_cfg.no_of_masters = 1;
    m_cfg_h = new[env_cfg.no_of_masters];
    
    foreach(m_cfg_h[i]) begin
        m_cfg_h[i] = m_config::type_id::create($sformatf("m_cfg_h[%0d]", i));
        if(!uvm_config_db #(virtual axi_if)::get(this, "", "vif", m_cfg_h[i].vif))
            `uvm_fatal("BASE_TEST", $sformatf("VIF not found for Master[%0d]", i))
        
        m_cfg_h[i].is_active = UVM_ACTIVE;
    end
    env_cfg.m_cfg = m_cfg_h;


    env_cfg.no_of_slaves = 1;
    s_cfg_h = new[env_cfg.no_of_slaves];
    
    foreach(s_cfg_h[i]) begin
        s_cfg_h[i] = s_config::type_id::create($sformatf("s_cfg_h[%0d]", i));
        if(!uvm_config_db #(virtual axi_if)::get(this, "", "vif", s_cfg_h[i].vif))
            `uvm_fatal("BASE_TEST", $sformatf("VIF not found for Slave[%0d]", i))
        
        s_cfg_h[i].is_active = UVM_ACTIVE;
    end
    env_cfg.s_cfg = s_cfg_h;

    env_cfg.has_scoreboard = 1;
    env_cfg.has_virtual_sequencer = 1;

    uvm_config_db #(env_config)::set(this, "*", "env_config", env_cfg);

    env_h = env::type_id::create("env_h", this);
endfunction

function void base_test::end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
endfunction


//-----------------------------------------------------------------------------
// INCREMENTAL BURST TEST
//-----------------------------------------------------------------------------
class incr_burst_test extends base_test;
    `uvm_component_utils(incr_burst_test)

    extern function new(string name = "incr_burst_test", uvm_component parent);
    extern virtual task run_phase(uvm_phase phase);
endclass

function incr_burst_test::new(string name = "incr_burst_test", uvm_component parent);
    super.new(name, parent);
endfunction

task incr_burst_test::run_phase(uvm_phase phase);
    v_incr_burst_test_seq vseq;
    
    phase.raise_objection(this);
    `uvm_info("TEST_START", "Objection raised", UVM_NONE)
    
    vseq = v_incr_burst_test_seq::type_id::create("vseq");
    `uvm_info("TEST_START", "Virtual sequence created", UVM_NONE)
    
    vseq.start(env_h.v_seqr);
    `uvm_info("TEST_START", "Virtual sequence completed", UVM_NONE)
    
    phase.drop_objection(this);
    `uvm_info("TEST_START", "Objection dropped", UVM_NONE)
endtask


//-----------------------------------------------------------------------------
// RAW HAZARD TEST
//-----------------------------------------------------------------------------
class raw_hazard_test extends base_test;
    `uvm_component_utils(raw_hazard_test)

    extern function new(string name = "raw_hazard_test", uvm_component parent);
    extern virtual task run_phase(uvm_phase phase);
endclass

function raw_hazard_test::new(string name = "raw_hazard_test", uvm_component parent);
    super.new(name, parent);
endfunction

task raw_hazard_test::run_phase(uvm_phase phase);
    v_raw_hazard_test_seq vseq;
    
    phase.raise_objection(this);
    `uvm_info("TEST_START", get_type_name(), UVM_NONE)

    uvm_test_done.set_drain_time(this, 500ns);
    
    vseq = v_raw_hazard_test_seq::type_id::create("vseq");
    vseq.start(env_h.v_seqr);
    
    phase.drop_objection(this);
endtask


//-----------------------------------------------------------------------------
// BURST VARIATION TEST
//-----------------------------------------------------------------------------
class burst_variation_test extends base_test;
    `uvm_component_utils(burst_variation_test)

    extern function new(string name = "burst_variation_test", uvm_component parent);
    extern virtual task run_phase(uvm_phase phase);
endclass

function burst_variation_test::new(string name = "burst_variation_test", uvm_component parent);
    super.new(name, parent);
endfunction

task burst_variation_test::run_phase(uvm_phase phase);
    v_burst_variation_test_seq vseq;
    
    phase.raise_objection(this);
    `uvm_info("TEST_START", get_type_name(), UVM_NONE)

    uvm_test_done.set_drain_time(this, 200ns);

    vseq = v_burst_variation_test_seq::type_id::create("vseq");
    vseq.start(env_h.v_seqr);
    
    phase.drop_objection(this);
endtask