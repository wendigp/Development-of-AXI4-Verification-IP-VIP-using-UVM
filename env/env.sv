//=============================================================================//
//ENVIRONMENT
//============================================================================//

class env extends uvm_env;

    `uvm_component_utils(env)

    env_config      env_cfg;
    master_uvc      m_uvc;
    slave_uvc       s_uvc;
    scoreboard      sb;
    v_sequencer     v_seqr;

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

    //OBJECT CREATION FOR AGENT_TOPS(MASTER_AGENT_TOP, SLAVE_AGENT_TOP)
    m_uvc = master_uvc::type_id::create("m_uvc",this);
    s_uvc = slave_uvc::type_id::create("s_uvc",this);

    //OBJECT CREATION OF SCOREBOARD AND VIRTUAL SEQUENCER IF EXIST
    if(env_cfg.has_scoreboard)
        sb = scoreboard::type_id::create("sb",this);

    if(env_cfg.has_virtual_sequencer)
        v_seqr = v_sequencer::type_id::create("v_seqr",this);
endfunction

function void env::connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if(env_cfg.has_scoreboard && sb != null)
        begin
            for(int i = 0; i < env_cfg.no_of_masters; i++) begin
                m_uvc.m_agent[i].monh.analysis_port.connect(sb.m_fifo[i].analysis_export);
                end

            for(int i = 0; i < env_cfg.no_of_slaves; i++) begin
                s_uvc.s_agent[i].monh.analysis_port.connect(sb.s_fifo[i].analysis_export);
                end
        end
    
    if(env_cfg.has_virtual_sequencer && v_seqr != null)
        begin
            for(int i = 0; i < env_cfg.no_of_masters; i++) begin
                v_seqr.m_seqrh[i] = m_uvc.m_agent[i].seqrh;
                end

            for(int i = 0; i< env_cfg.no_of_slaves;i++) begin
                v_seqr.s_seqrh[i] = s_uvc.s_agent[i].seqrh;
                end
        end
endfunction
