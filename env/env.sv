//=============================================================================//
// ENVIRONMENT
//============================================================================//

class env extends uvm_env;

    `uvm_component_utils(env)

    env_config      env_cfg;
    master_uvc      m_uvc;
    slave_uvc       s_uvc;
    scoreboard      sb;
    v_sequencer     v_seqr;
    
    // Declaration of the Functional Coverage Subscribers
    axi_subscriber  m_subscriber[];
    axi_subscriber  s_subscriber[];

    extern function new(string name = "env", uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern function void connect_phase(uvm_phase phase);
endclass

function env::new(string name = "env", uvm_component parent);
    super.new(name,parent);
endfunction

function void env::build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db #(env_config)::get(this,"","env_config",env_cfg))
        `uvm_fatal("ENVIRONMENT", "CANNOT GET DATA FROM ENV_CONFIG. HAVE YOU SET IT?")

    `uvm_info("ENV", $sformatf("ENV built with %0d masters and %0d slaves",env_cfg.no_of_masters, env_cfg.no_of_slaves),UVM_LOW)

    if (env_cfg.m_cfg.size() != env_cfg.no_of_masters)
        `uvm_fatal("ENV", $sformatf("Master cfg size mismatch: Expected %0d, Got %0d", env_cfg.no_of_masters, env_cfg.m_cfg.size()))
    
    if (env_cfg.s_cfg.size() != env_cfg.no_of_slaves)
        `uvm_fatal("ENV", $sformatf("Slave cfg size mismatch: Expected %0d, Got %0d", env_cfg.no_of_slaves, env_cfg.s_cfg.size()))

    // OBJECT CREATION FOR AGENT_TOPS
    m_uvc = master_uvc::type_id::create("m_uvc",this);
    s_uvc = slave_uvc::type_id::create("s_uvc",this);

    // OBJECT CREATION OF SCOREBOARD AND VIRTUAL SEQUENCER
    if(env_cfg.has_scoreboard)
        sb = scoreboard::type_id::create("sb",this);

    if(env_cfg.has_virtual_sequencer)
        v_seqr = v_sequencer::type_id::create("v_seqr",this);

    // OBJECT CREATION FOR MASTER SUBSCRIBERS
    m_subscriber = new[env_cfg.no_of_masters];
    for(int i = 0; i < env_cfg.no_of_masters; i++) begin
        m_subscriber[i] = axi_subscriber::type_id::create($sformatf("m_subscriber_%0d", i), this);
        
        // Pass the VIF specific to this master agent from the master configuration
        uvm_config_db #(virtual axi_if)::set(this, $sformatf("m_subscriber_%0d", i), "vif", env_cfg.m_cfg[i].vif);
    end

    // OBJECT CREATION FOR SLAVE SUBSCRIBERS
    s_subscriber = new[env_cfg.no_of_slaves];
    for(int i = 0; i < env_cfg.no_of_slaves; i++) begin
        s_subscriber[i] = axi_subscriber::type_id::create($sformatf("s_subscriber_%0d", i), this);
        
        //Pass the VIF specific to this slave agent from the slave configuration
        uvm_config_db #(virtual axi_if)::set(this, $sformatf("s_subscriber_%0d", i), "vif", env_cfg.s_cfg[i].vif);
    end
endfunction

function void env::connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Scoreboard Connections
    if(env_cfg.has_scoreboard && sb != null) begin
        for(int i = 0; i < env_cfg.no_of_masters; i++) begin
            m_uvc.m_agent[i].monh.analysis_port.connect(sb.m_fifo.analysis_export);
        end

        for(int i = 0; i < env_cfg.no_of_slaves; i++) begin
            s_uvc.s_agent[i].monh.analysis_port.connect(sb.s_fifo.analysis_export);
        end
    end
    
    // Virtual Sequencer Connections
    if(env_cfg.has_virtual_sequencer && v_seqr != null) begin
        for(int i = 0; i < env_cfg.no_of_masters; i++) begin
            v_seqr.m_seqrh[i] = m_uvc.m_agent[i].seqrh;
        end

        for(int i = 0; i < env_cfg.no_of_slaves; i++) begin
            v_seqr.s_seqrh[i] = s_uvc.s_agent[i].seqrh;
        end
    end

    // Coverage Connections (Master Side)
    for(int i = 0; i < env_cfg.no_of_masters; i++) begin
        m_uvc.m_agent[i].monh.analysis_port.connect(m_subscriber[i].analysis_export);
    end

    // Coverage Connections (Slave Side)
    for(int i = 0; i < env_cfg.no_of_slaves; i++) begin
        s_uvc.s_agent[i].monh.analysis_port.connect(s_subscriber[i].analysis_export);
    end

endfunction