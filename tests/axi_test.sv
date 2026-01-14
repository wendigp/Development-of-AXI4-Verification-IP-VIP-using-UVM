//==============================================================================//
// AXI TOP LEVEL TESTS
// Implementation: 
//   - Configures the Verification Environment
//   - Distributes Virtual Interfaces via config_db
//   - Initiates Virtual Sequences on the Virtual Sequencer
//==============================================================================//

//-----------------------------------------------------------------------------
// BASE TEST
// Logic: The foundation for all tests. Sets up env_config and builds the env.
//-----------------------------------------------------------------------------
class base_test extends uvm_test;
    `uvm_component_utils(base_test)

    env             env_h;
    env_config      env_cfg;
    m_config        m_cfg_h[];
    s_config        s_cfg_h[];

    function new(string name = "base_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    //-------------------------------------------------------------------------
    // BUILD PHASE
    //-------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 1. Create Top Level Env Config
        env_cfg = env_config::type_id::create("env_cfg");
        
        // 2. Configure Master Agent(s)
        env_cfg.no_of_masters = 1;
        m_cfg_h = new[env_cfg.no_of_masters];
        
        foreach(m_cfg_h[i]) begin
            m_cfg_h[i] = m_config::type_id::create($sformatf("m_cfg_h[%0d]", i));
            // Get virtual interface from top-level TB
            if(!uvm_config_db #(virtual axi_if)::get(this, "", "vif", m_cfg_h[i].vif))
                `uvm_fatal("BASE_TEST", $sformatf("VIF not found for Master[%0d]", i))
            
            m_cfg_h[i].is_active = UVM_ACTIVE;
        end
        env_cfg.m_cfg = m_cfg_h;

        // 3. Configure Slave Agent(s)
        env_cfg.no_of_slaves = 1;
        s_cfg_h = new[env_cfg.no_of_slaves];
        
        foreach(s_cfg_h[i]) begin
            s_cfg_h[i] = s_config::type_id::create($sformatf("s_cfg_h[%0d]", i));
            // Get virtual interface from top-level TB
            if(!uvm_config_db #(virtual axi_if)::get(this, "", "vif", s_cfg_h[i].vif))
                `uvm_fatal("BASE_TEST", $sformatf("VIF not found for Slave[%0d]", i))
            
            s_cfg_h[i].is_active = UVM_ACTIVE;
        end
        env_cfg.s_cfg = s_cfg_h;

        // 4. Set global knobs
        env_cfg.has_scoreboard = 1;
        env_cfg.has_virtual_sequencer = 1;

        // 5. Store in config_db for the Env to retrieve
        uvm_config_db #(env_config)::set(this, "*", "env_config", env_cfg);

        // 6. Create the Environment
        env_h = env::type_id::create("env_h", this);
    endfunction

    //-------------------------------------------------------------------------
    // END OF ELABORATION PHASE
    //-------------------------------------------------------------------------
    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        // Print topology to verify hierarchy and connections
        uvm_top.print_topology();
    endfunction
endclass

//-----------------------------------------------------------------------------
// INCREMENTAL BURST TEST
// Logic: Executes a sequence focused on INCR burst types
//-----------------------------------------------------------------------------
class incr_burst_test extends base_test;
    `uvm_component_utils(incr_burst_test)

    function new(string name = "incr_burst_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
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
endclass

//-----------------------------------------------------------------------------
// RAW HAZARD TEST
// Logic: Executes a sequence specifically generating Read-After-Write scenarios
//-----------------------------------------------------------------------------
class raw_hazard_test extends base_test;
    `uvm_component_utils(raw_hazard_test)

    function new(string name = "raw_hazard_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        v_raw_hazard_test_seq vseq;
        
        phase.raise_objection(this);
        `uvm_info("TEST_START", get_type_name(), UVM_NONE)

        // Advanced Drain Time
        uvm_test_done.set_drain_time(this, 500ns);
        
        vseq = v_raw_hazard_test_seq::type_id::create("vseq");
        
        // Start virtual sequence
        vseq.start(env_h.v_seqr);
        
        phase.drop_objection(this);
    endtask
endclass

//-----------------------------------------------------------------------------
// BURST VARIATION TEST
// Logic: Exercises FIXED and WRAP bursts in parallel via virtual sequence
//-----------------------------------------------------------------------------
class burst_variation_test extends base_test;
    `uvm_component_utils(burst_variation_test)

    function new(string name = "burst_variation_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        v_burst_variation_test_seq vseq;
        
        phase.raise_objection(this);
        `uvm_info("TEST_START", get_type_name(), UVM_NONE)

        // Advanced Drain Time
        uvm_test_done.set_drain_time(this, 200ns);

        vseq = v_burst_variation_test_seq::type_id::create("vseq");
        vseq.start(env_h.v_seqr);
        
        phase.drop_objection(this);
    endtask
endclass