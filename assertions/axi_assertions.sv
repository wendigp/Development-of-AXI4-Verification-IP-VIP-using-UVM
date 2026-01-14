//==============================================================================//
// AXI4 PROTOCOL CHECKERS (SVA)
// Scope:
//   - Handshake integrity
//   - Control & response stability
//   - Reset compliance
//   - Runtime enable via +ASSERT_ON
//==============================================================================//

interface axi_assertions #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
)(
    input logic aclk,
    input logic aresetn,

    // Write Address
    input logic [ID_WIDTH-1:0]   AWID,
    input logic [ADDR_WIDTH-1:0] AWADDR,
    input logic [7:0]            AWLEN,
    input logic [2:0]            AWSIZE,
    input logic [1:0]            AWBURST,
    input logic                  AWVALID,
    input logic                  AWREADY,

    // Write Data
    input logic [DATA_WIDTH-1:0]   WDATA,
    input logic [DATA_WIDTH/8-1:0] WSTRB,
    input logic                    WVALID,
    input logic                    WREADY,
    input logic                    WLAST,

    // Write Response
    input logic [ID_WIDTH-1:0]   BID,
    input logic [1:0]            BRESP,
    input logic                  BVALID,
    input logic                  BREADY,

    // Read Address
    input logic [ID_WIDTH-1:0]   ARID,
    input logic [ADDR_WIDTH-1:0] ARADDR,
    input logic [7:0]            ARLEN,
    input logic [2:0]            ARSIZE,
    input logic [1:0]            ARBURST,
    input logic                  ARVALID,
    input logic                  ARREADY,

    // Read Data
    input logic [ID_WIDTH-1:0]   RID,
    input logic [DATA_WIDTH-1:0] RDATA,
    input logic [1:0]            RRESP,
    input logic                  RVALID,
    input logic                  RREADY,
    input logic                  RLAST
);

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    //--------------------------------------------------------------------------
    // ASSERTION ENABLE CONTROL (Runtime)
    //--------------------------------------------------------------------------
    bit assert_en;

    initial begin
        assert_en = $test$plusargs("ASSERT_ON");
        if (assert_en)
            `uvm_info("AXI_ASSERT", "AXI assertions ENABLED", UVM_LOW)
        else
            `uvm_info("AXI_ASSERT", "AXI assertions DISABLED", UVM_LOW)
    end

    //--------------------------------------------------------------------------
    // 1. HANDSHAKE INTEGRITY
    //--------------------------------------------------------------------------

    property p_awvalid_held;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        (AWVALID && !AWREADY) |=> AWVALID;
    endproperty
    assert_awvalid_held:
        assert property (p_awvalid_held)
        else `uvm_error("AXI_ERR_VALID", "AWVALID dropped before AWREADY");

    property p_wvalid_held;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        (WVALID && !WREADY) |=> WVALID;
    endproperty
    assert_wvalid_held:
        assert property (p_wvalid_held)
        else `uvm_error("AXI_ERR_VALID", "WVALID dropped before WREADY");

    property p_arvalid_held;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        (ARVALID && !ARREADY) |=> ARVALID;
    endproperty
    assert_arvalid_held:
        assert property (p_arvalid_held)
        else `uvm_error("AXI_ERR_VALID", "ARVALID dropped before ARREADY");

    property p_rvalid_held;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        (RVALID && !RREADY) |=> RVALID;
    endproperty
    assert_rvalid_held:
        assert property (p_rvalid_held)
        else `uvm_error("AXI_ERR_VALID", "RVALID dropped before RREADY");

    //--------------------------------------------------------------------------
    // 2. CONTROL & ADDRESS STABILITY
    //--------------------------------------------------------------------------

    property p_aw_stable;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        (AWVALID && !AWREADY) |=> $stable({AWADDR, AWLEN, AWSIZE, AWBURST, AWID});
    endproperty
    assert_aw_stable:
        assert property (p_aw_stable)
        else `uvm_error("AXI_ERR_STABLE", "AW control changed during handshake");

    property p_ar_stable;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        (ARVALID && !ARREADY) |=> $stable({ARADDR, ARLEN, ARSIZE, ARBURST, ARID});
    endproperty
    assert_ar_stable:
        assert property (p_ar_stable)
        else `uvm_error("AXI_ERR_STABLE", "AR control changed during handshake");

    property p_wdata_stable;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        (WVALID && !WREADY) |=> $stable({WDATA, WSTRB, WLAST});
    endproperty
    assert_wdata_stable:
        assert property (p_wdata_stable)
        else `uvm_error("AXI_ERR_STABLE", "WDATA/WSTRB/WLAST changed");

    //--------------------------------------------------------------------------
    // 3. RESPONSE STABILITY
    //--------------------------------------------------------------------------

    property p_bresp_stable;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        (BVALID && !BREADY) |=> $stable(BRESP);
    endproperty
    assert_bresp_stable:
        assert property (p_bresp_stable)
        else `uvm_error("AXI_ERR_STABLE", "BRESP changed during handshake");

    property p_rresp_stable;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        (RVALID && !RREADY) |=> $stable(RRESP);
    endproperty
    assert_rresp_stable:
        assert property (p_rresp_stable)
        else `uvm_error("AXI_ERR_STABLE", "RRESP changed during handshake");

    //--------------------------------------------------------------------------
    // 4. RESET COMPLIANCE
    //--------------------------------------------------------------------------

    property p_reset_valid_low;
        @(posedge aclk)
        disable iff (!assert_en)
        !aresetn |-> (!AWVALID && !WVALID && !ARVALID && !BVALID && !RVALID);
    endproperty
    assert_reset_valid_low:
        assert property (p_reset_valid_low)
        else `uvm_error("AXI_ERR_RESET", "VALID high during reset");

    //--------------------------------------------------------------------------
    // 5. PROTOCOL-SPECIFIC CHECKS
    //--------------------------------------------------------------------------

    property p_wstrb_not_zero;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        WVALID |-> (WSTRB != 0);
    endproperty
    assert_wstrb_not_zero:
        assert property (p_wstrb_not_zero)
        else `uvm_error("AXI_ERR_STRB", "WSTRB is zero during WVALID");

    property p_rlast_stable;
        @(posedge aclk)
        disable iff (!aresetn || !assert_en)
        (RVALID && !RREADY) |=> $stable(RLAST);
    endproperty
    assert_rlast_stable:
        assert property (p_rlast_stable)
        else `uvm_error("AXI_ERR_STABLE", "RLAST changed during handshake");

endinterface

