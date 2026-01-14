//==============================================================================
// AXI DEFINITIONS PACKAGE
// Purpose:
//   - Centralized AXI parameters
//   - Shared enums and constants
//   - Used by ALL VIP components
//==============================================================================

package axi_defs;

    //--------------------------------------------------------------------------
    // AXI4 Bus Width Parameters
    //--------------------------------------------------------------------------
    parameter int ADDR_WIDTH = 32;
    parameter int DATA_WIDTH = 32;
    parameter int ID_WIDTH   = 4;
    parameter int LEN_WIDTH =  8;

    //--------------------------------------------------------------------------
    // AXI Burst Types
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {
        FIXED = 2'b00,
        INCR  = 2'b01,
        WRAP  = 2'b10,
        RSVD  = 2'b11
    } axi_burst_e;

    //--------------------------------------------------------------------------
    // AXI Response Types
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {
        OKAY   = 2'b00,
        EXOKAY = 2'b01,
        SLVERR = 2'b10,
        DECERR = 2'b11
    } axi_resp_e;

endpackage : axi_defs
