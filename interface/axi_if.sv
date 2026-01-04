//AXI INTERFACE

interface axi_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int ID_WIDTH   = 4,
  parameter int LEN_WIDTH  = 8
					)
					(input bit ACLK);

//===========GLOBAL SIGNALS ===================//
	logic ARESETn;
	
//===========WRITE ADDRESS CHANNEL ============//
	logic [ID_WIDTH - 1:0]		AWID;
	logic [ADDR_WIDTH - 1:0]	AWADDR;
	logic [LEN_WIDTH-1 :0] 		AWLEN;
	logic [2:0] 				AWSIZE;
	logic [1:0] 				AWBURST;
	logic						AWVALID;
	logic						AWREADY;
	
//==========WRITE DATA CHANNEL ================//
	logic [DATA_WIDTH-1:0]		WDATA;
	logic [(DATA_WIDTH/8)-1:0] 	WSTRB;
	logic 						WLAST;
	logic						WVALID;
	logic						WREADY;
	
//==========WRITE RESPONSE CHANNEL ============//
	logic [ID_WIDTH-1:0]	BID;
	logic [1:0] 			BRESP;
	logic					BVALID;
	logic					BREADY;
	
//===========READ ADDRESS CHANNEL ============//
	logic [ID_WIDTH-1:0]		ARID;
	logic [ADDR_WIDTH-1:0]		ARADDR;
	logic [LEN_WIDTH-1:0] 		ARLEN;
	logic [2:0] 				ARSIZE;
	logic [1:0] 				ARBURST;
	logic						ARVALID;
	logic						ARREADY;
	
//==========READ DATA CHANNEL ================//
	logic [ID_WIDTH-1:0]		RID;
	logic [DATA_WIDTH-1:0]		RDATA;
	logic [1:0] 				RRESP;
	logic 						RLAST;
	logic						RVALID;
	logic						RREADY;		

//=============== MASTER DRIVER CLOCKING BLOCK ========//
clocking drv_cb_m @(posedge ACLK);
	default input #1 output #0;
	
	output ARESETn;
	
	//WRITE ADDRESS CHANNEL
	input 	AWREADY;
	output 	AWADDR, AWBURST, AWID, AWLEN, AWSIZE, AWVALID;
	
	//WRITE DATA CHANNEL
	input	WREADY;
	output	WDATA, WSTRB, WLAST, WVALID;
	
	//WRITE RESPONSE CHANNEL
	input	BID, BRESP, BVALID;
	output	BREADY;
	
	//READ ADDRESS CHANNEL
	input 	ARREADY;
	output 	ARADDR, ARBURST, ARID, ARLEN, ARSIZE, ARVALID;
	
	//READ DATA CHANNEL
	input	RDATA, RID, RRESP, RLAST, RVALID;
	output	RREADY;
endclocking

//=============== MASTER MONITOR CLOCKING BLOCK ========//
clocking mon_cb_m @(posedge ACLK);
	default input #1 output #0;
	
	input ARESETn;
	
	//WRITE ADDRESS CHANNEL
	input 	AWREADY;
	input 	AWADDR, AWBURST, AWID, AWLEN, AWSIZE, AWVALID;
	
	//WRITE DATA CHANNEL
	input	WREADY;
	input	WDATA, WSTRB, WLAST, WVALID;
	
	//WRITE RESPONSE CHANNEL
	input	BID, BRESP, BVALID;
	input	BREADY;
	
	//READ ADDRESS CHANNEL
	input 	ARREADY;
	input 	ARADDR, ARBURST, ARID, ARLEN, ARSIZE, ARVALID;
	
	//READ DATA CHANNEL
	input	RDATA, RID, RRESP, RLAST, RVALID;
	input	RREADY;
endclocking

//=============== SLAVE DRIVER CLOCKING BLOCK ========//
clocking drv_cb_s @(posedge ACLK);
	default input #1 output #0;
	
	input ARESETn;
	
	//WRITE ADDRESS CHANNEL
	output 	AWREADY;
	input 	AWADDR, AWBURST, AWID, AWLEN, AWSIZE, AWVALID;
	
	//WRITE DATA CHANNEL
	output	WREADY;
	input	WDATA, WSTRB, WLAST, WVALID;
	
	//WRITE RESPONSE CHANNEL
	output	BID, BRESP, BVALID;
	input	BREADY;
	
	//READ ADDRESS CHANNEL
	output 	ARREADY;
	input 	ARADDR, ARBURST, ARID, ARLEN, ARSIZE, ARVALID;
	
	//READ DATA CHANNEL
	output	RDATA, RID, RRESP, RLAST, RVALID;
	input	RREADY;
endclocking

//=============== SLAVE MONITOR CLOCKING BLOCK ========//
clocking mon_cb_s @(posedge ACLK);
	default input #1 output #0;
	
	input ARESETn;
	
	//WRITE ADDRESS CHANNEL
	input 	AWREADY;
	input 	AWADDR, AWBURST, AWID, AWLEN, AWSIZE, AWVALID;
	
	//WRITE DATA CHANNEL
	input	WREADY;
	input	WDATA, WSTRB, WLAST, WVALID;
	
	//WRITE RESPONSE CHANNEL
	input	BID,BRESP, BVALID;
	input	BREADY;
	
	//READ ADDRESS CHANNEL
	input 	ARREADY;
	input 	ARADDR, ARBURST, ARID, ARLEN, ARSIZE, ARVALID;
	
	//READ DATA CHANNEL
	input	RDATA, RID, RRESP, RLAST, RVALID;
	input	RREADY;
endclocking

//===============MODPORTS =============================//
	modport DRV_MP_M (clocking drv_cb_m);
	modport MON_MP_M (clocking mon_cb_m);
	modport DRV_MP_S (clocking drv_cb_s);
	modport MON_MP_S (clocking mon_cb_s);


endinterface