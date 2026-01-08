//==============================================================================================//
//ASSERTIONS
//=============================================================================================//
interface axi_assertions #(
                parameter ADDR_WIDTH = 32,
                parameter ID_WIDTH = 4,
                paarmeter LEN_WIDTH = 8,
                parameter DATA_WIDTH = 32)      
    (
            input logic AWCLK,
            input logic AudioProcessingEvent,

            //WRITE ADDR CHANNEL
            input logic [ADDR_WIDTH-1:0] AWADDR,
            lnput logic [ID_WIDTH-1:0] AWID

)