`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/08/03 13:04:41
// Design Name: 
// Module Name: forward_sub1
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


module forward_sub1(

    input wire clk,
    input wire rst,
    input wire flush,
    input wire flush_cause,
    input wire [3:0] stall,
    input wire is_in_delayslot,
    
    input wire re1,
    input wire [`RegAddrBus] raddr1,
    input wire [`RegBus] rdata1,
    input wire re2,
    input wire [`RegAddrBus] raddr2,
    input wire [`RegBus] rdata2,
    
    input wire [`RegBus] imm,
    input wire ex_we_i1,
    input wire [`RegBus] ex_wdata_i1,
    input wire [`RegAddrBus] ex_waddr_i1,
    input wire ex_we_i2,
    input wire [`RegBus] ex_wdata_i2,
    input wire [`RegAddrBus] ex_waddr_i2,
    
    input wire mem_we_i1,
    input wire [`RegBus] mem_wdata_i1,
    input wire [`RegAddrBus] mem_waddr_i1,
    input wire mem_we_i2,
    input wire [`RegBus] mem_wdata_i2,
    input wire [`RegAddrBus] mem_waddr_i2,
    
    output wire [`RegBus] reg1_o,
    output wire [`RegBus] reg2_o
    
    );
    
    reg [`RegBus] reg1_temp, reg2_temp;
    reg reg1_valid, reg2_valid;
    
    assign reg1_o = reg1_temp & {32{reg1_valid}};
    assign reg2_o = reg2_temp & {32{reg2_valid}};
    
    always @ (posedge clk) begin
        if(rst == `RstEnable)
            reg1_temp <= `ZeroWord;
        else if (&stall[1:0])
            reg1_temp <= reg1_temp;
        else if((re1 == 1'b1) && (ex_we_i2 == 1'b1) && (ex_waddr_i2 == raddr1))
            reg1_temp <= ex_wdata_i2; 
        else if((re1 == 1'b1) && (ex_we_i1 == 1'b1) && (ex_waddr_i1 == raddr1))
            reg1_temp <= ex_wdata_i1; 
        else if((re1 == 1'b1) && (mem_we_i2 == 1'b1) && (mem_waddr_i2 == raddr1))
            reg1_temp <= mem_wdata_i2;
        else if((re1 == 1'b1) && (mem_we_i1 == 1'b1) && (mem_waddr_i1 == raddr1))
            reg1_temp <= mem_wdata_i1;
        else if(re1 == 1'b1)
            reg1_temp <= rdata1;
        else if(re1 == 1'b0)
            reg1_temp <= imm;
        else
            reg1_temp <= `ZeroWord;
    end
    
    always @ (posedge clk) begin
        if(rst == `RstEnable)
            reg2_temp <= `ZeroWord;      
        else if (&stall[1:0])
            reg2_temp <= reg2_temp;
        else if((re2 == 1'b1) && (ex_we_i2 == 1'b1) && (ex_waddr_i2 == raddr2))
            reg2_temp <= ex_wdata_i2; 
        else if((re2 == 1'b1) && (ex_we_i1 == 1'b1) && (ex_waddr_i1 == raddr2))
            reg2_temp <= ex_wdata_i1; 
        else if((re2 == 1'b1) && (mem_we_i2 == 1'b1) && (mem_waddr_i2 == raddr2))
            reg2_temp <= mem_wdata_i2;
        else if((re2 == 1'b1) && (mem_we_i1 == 1'b1) && (mem_waddr_i1 == raddr2))
            reg2_temp <= mem_wdata_i1;
        else if(re2 == 1'b1)
            reg2_temp <= rdata2;
        else if(re2 == 1'b0)
            reg2_temp <= imm;
        else
            reg2_temp <= `ZeroWord;
    end
    
    always @ (posedge clk) begin
		if (rst == `RstEnable) begin
            reg1_valid <= 1'b0;
            reg2_valid <= 1'b0;
        end else if (flush == 1'b1 && flush_cause == `Exception) begin
            reg1_valid <= 1'b0;
            reg2_valid <= 1'b0;
        end else if (flush == 1'b1 && flush_cause == `FailedBranchPrediction && is_in_delayslot == `InDelaySlot) begin
            reg1_valid <= 1'b1;
            reg2_valid <= 1'b1;
        end else if (flush == 1'b1 && flush_cause == `FailedBranchPrediction && is_in_delayslot == `NotInDelaySlot) begin
            reg1_valid <= 1'b0;
            reg2_valid <= 1'b0;
        end else if (stall[0] == `Stop && stall[1] == `NoStop) begin
            reg1_valid <= 1'b0;
            reg2_valid <= 1'b0;
		end else if (stall[0] == `NoStop) begin		
            reg1_valid <= 1'b1;
            reg2_valid <= 1'b1;
		end
	end
	
endmodule
