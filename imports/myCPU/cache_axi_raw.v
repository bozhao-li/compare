`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/01 20:28:43
// Design Name: 
// Module Name: cache_axi_raw
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define AXI_RD_IDLE         3'b000
`define AXI_RD_DATA         3'b001
`define AXI_RD_INST         3'b010
`define AXI_RD_DATA2        3'b011
`define AXI_RD_INST2        3'b100

`define AXI_WR_IDLE         2'b00
`define AXI_WR_DUNCACHE     2'b01
`define AXI_WR_DCACHE       2'b10

module axi_sel(
    input wire clk,
    input wire resetn,
    input wire flush,
    input wire fail_flush_inst,
    input wire fail_flush_data,

// cache: from cache, to cache
    // inst read
    input wire iuncache,
    input wire [7:0] ird_len,
    input wire ird_req,
    input wire [`RegBus] ird_addr,
    output wire ird_valid,
    output wire [255:0] ird_data,

    // data read
    input wire duncache,
    input wire [7:0] drd_len,
    input wire [2:0] drd_arsize,
    input wire drd_req,
    input wire [`RegBus] drd_addr,
    output wire [255:0] drd_data,
    output wire drd_valid,

    // write
    input wire [1:0] judge,
    input wire [7:0] dwr_len,
    input wire dwr_req,
    input wire [`RegBus] dwr_addr,
    input wire [255:0] dwr_data,
    input wire [3:0] dwr_wstrb,
    
// axi: from axi, to axi
    output wire [7:0] axi_rd_len,
    output wire axi_rd_req,
    output wire [2:0] axi_rd_arsize,
    output wire [31:0] axi_rd_addr,
    output wire [3:0] axi_rd_arid,
    input wire [255:0] axi_rd_data,
    input wire [3:0] axi_rd_rid,
    input wire [1:0]axi_rd_cnt,
    input wire axi_rd_valid,
    input wire fsh,
    
    output wire [7:0] axi_wr_len,
    output wire axi_wr_req,
    output wire [31:0] axi_wr_addr,
    output wire [255:0] axi_wr_data,
    output wire [3:0] axi_wr_wstrb,
    input wire axi_wr_valid

    
    );

    reg [2:0] rcur_state;
    wire dcache_rd_req = drd_req & ~duncache;
    wire duncache_rd_req = drd_req & duncache;
    wire icache_rd_req = ird_req & ~iuncache;
    wire iuncache_rd_req = ird_req & iuncache;
    
(*mark_debug = "true"*)    reg [1:0] wcur_state;
    wire dcache_wr_req = dwr_req & judge[1];
    wire duncache_wr_req = dwr_req & judge[0];
    
    reg axi_rd_valid_ff;
    
    wire dcache_rd_cond = ~dcache_wr_req ? 1'b1 : (drd_addr != dwr_addr); 
    
    reg [3:0]axi_rd_rid_ff;
    
    always @(posedge clk) begin
        if(~resetn) begin
            axi_rd_rid_ff <= 4'd0;
        end
        else begin
            axi_rd_rid_ff <= axi_rd_rid;
        end
    end
    
    always @ (posedge clk) begin
        if (~resetn)
            axi_rd_valid_ff <= 1'b0;
        else
            axi_rd_valid_ff <= axi_rd_valid;
    end
    
    always @ (posedge clk) begin
        if (~resetn | flush)
            rcur_state <= `AXI_RD_IDLE;
        else
            case (rcur_state)
                `AXI_RD_IDLE:       rcur_state <= (~duncache_wr_req & duncache_rd_req) ? `AXI_RD_DATA :
                                                (dcache_rd_cond & dcache_rd_req) ? `AXI_RD_DATA :
                                                (~duncache_wr_req & iuncache_rd_req) ? `AXI_RD_INST :
                                                icache_rd_req ? `AXI_RD_INST : `AXI_RD_IDLE;
                `AXI_RD_DATA:       rcur_state <= (axi_rd_cnt == 3'b01 & ird_req) ? `AXI_RD_INST2 :
                                                  (drd_valid) ? `AXI_RD_IDLE : `AXI_RD_DATA;
                `AXI_RD_INST:       rcur_state <= (axi_rd_cnt == 2'b01 & drd_req) ? `AXI_RD_DATA2 :
                                                  (ird_valid) ? `AXI_RD_IDLE : `AXI_RD_INST;
                `AXI_RD_DATA2:      rcur_state <= (drd_valid) ? `AXI_RD_INST : 
                                                  (ird_valid) ? `AXI_RD_DATA : `AXI_RD_DATA2;
                `AXI_RD_INST2:      rcur_state <= (ird_valid) ? `AXI_RD_DATA : 
                                                  (drd_valid) ? `AXI_RD_INST : `AXI_RD_INST2;
                default:            rcur_state <= `AXI_RD_IDLE;  // to be discussed
            endcase
    end
    
    // rd_output 
    // rd_req
    assign axi_rd_req = (rcur_state == `AXI_RD_DATA | rcur_state == `AXI_RD_DATA2) ? drd_req :  // ÓÃstate¾ö¶¨
                        (rcur_state == `AXI_RD_INST | rcur_state == `AXI_RD_INST2) ? ird_req : 1'b0;
    
    // rd_addr
    assign axi_rd_addr = (rcur_state == `AXI_RD_DATA | rcur_state == `AXI_RD_DATA2) ? drd_addr :
                         (rcur_state == `AXI_RD_INST | rcur_state == `AXI_RD_INST2) ? ird_addr : 32'b0;
    // rd_len
    assign axi_rd_len = (rcur_state == `AXI_RD_DATA | rcur_state == `AXI_RD_DATA2) ? drd_len :
                        (rcur_state == `AXI_RD_INST | rcur_state == `AXI_RD_INST2) ? ird_len : 7'b0;
                        
    assign axi_rd_arsize = (rcur_state == `AXI_RD_DATA | rcur_state == `AXI_RD_DATA2) ? drd_arsize : 3'b010; 
    
    assign axi_rd_arid = (rcur_state == `AXI_RD_DATA | rcur_state == `AXI_RD_DATA2) ? 4'b0001 :
                         (rcur_state == `AXI_RD_INST | rcur_state == `AXI_RD_INST2) ? 4'b0000 : 4'b0001;
                        
    // valid
    assign ird_valid = axi_rd_rid_ff == 4'b0000 & axi_rd_valid_ff & ~fail_flush_inst;        
    assign drd_valid = axi_rd_rid_ff == 4'b0001 & axi_rd_valid_ff & ~fail_flush_data;
    
    // rd_data
    assign drd_data = (axi_rd_valid_ff & axi_rd_rid_ff == 4'b0001) ? axi_rd_data : 256'b0;
    assign ird_data = (axi_rd_valid_ff & axi_rd_rid_ff == 4'b0000) ? axi_rd_data : 256'b0;
    
    always @(posedge clk) begin
        if (~resetn)
            wcur_state <= `AXI_WR_IDLE;
        else
            case (wcur_state)
                `AXI_WR_IDLE:       wcur_state <= duncache_wr_req ? `AXI_WR_DUNCACHE :
                                                dcache_wr_req ? `AXI_WR_DCACHE : `AXI_WR_IDLE;
                `AXI_WR_DUNCACHE:   wcur_state <= axi_wr_valid ? `AXI_WR_IDLE : `AXI_WR_DUNCACHE;
                `AXI_WR_DCACHE:     wcur_state <= axi_wr_valid ? `AXI_WR_IDLE : `AXI_WR_DCACHE;
                default:            wcur_state <= `AXI_WR_IDLE;
            endcase
    end
           
    
    // wr_output
    // wr_req
(*mark_debug = "true"*)    assign axi_wr_req = (wcur_state == `AXI_WR_DUNCACHE) ? duncache_wr_req :
                        (wcur_state == `AXI_WR_DCACHE) ? dcache_wr_req : 1'b0;      
    // wr_len
(*mark_debug = "true"*)    assign axi_wr_len = ((wcur_state == `AXI_WR_DUNCACHE)|(wcur_state == `AXI_WR_DCACHE)) ? dwr_len : 8'b0;
    // wr_addr
(*mark_debug = "true"*)    assign axi_wr_addr = ((wcur_state == `AXI_WR_DUNCACHE)|(wcur_state == `AXI_WR_DCACHE)) ? dwr_addr : 32'b0;                            
    // wr_data
(*mark_debug = "true"*)    assign axi_wr_data = ((wcur_state == `AXI_WR_DCACHE)|(wcur_state == `AXI_WR_DUNCACHE)) ? dwr_data : 256'b0;
    // wr_wstrb
(*mark_debug = "true"*)    assign axi_wr_wstrb = ((wcur_state == `AXI_WR_DCACHE)|(wcur_state == `AXI_WR_DUNCACHE)) ? dwr_wstrb : 4'b1111;
    
    

endmodule
