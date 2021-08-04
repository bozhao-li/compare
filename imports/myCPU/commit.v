`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/09 21:46:55
// Design Name: 
// Module Name: commit
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

`include "defines.v"
module commit(

	input wire clk,
	input wire rst,
	input wire flush,
	input wire flush_cause,
	input wire exception_inst_sel,
	input wire [3:0] stall,
	
	// 来自访存阶段的信息
    input wire LLbit_i,
    input wire LLbit_we_i,
    
    // 特权指令有关的信息
    input wire [2:0] cp0_wsel_i,
    input wire cp0_we_i,
    input wire [4:0] cp0_waddr_i,
    input wire [`RegBus] cp0_wdata_i,
    
	// 第一条指令的信息	
	input wire [`RegAddrBus] waddr_i1,
	input wire we_i1,
	input wire [`RegBus] wdata_i1,
	input wire [`RegBus] inst_addr_i1,
	
    // 第二条指令的信息	
	input wire [`RegAddrBus] waddr_i2,
    input wire we_i2,
    input wire [`RegBus] wdata_i2,
    input wire [`RegBus] inst_addr_i2,

	// 送到寄存器堆的信息
	output reg LLbit_o,
	output reg LLbit_we_o,
	
	// 特权指令有关的信息
	output reg [2:0] cp0_wsel_o,
	output reg cp0_we_o,
	output reg [4:0] cp0_waddr_o,
	output reg [`RegBus] cp0_wdata_o,
	
	// 第一条指令的信息
	output reg [`RegAddrBus] waddr_o1,
	output reg we_o1,
	output reg [`RegBus] wdata_o1,
	output reg [`RegBus] inst_addr_o1,
	
	// 第二条指令的信息
	output reg [`RegAddrBus] waddr_o2,
    output reg we_o2,
    output reg [`RegBus] wdata_o2,
    output reg [`RegBus] inst_addr_o2,
    
    // pref_debug
    input wire [`RegBus] pref_addr_i,
    output reg [`RegBus] pref_addr_o
);

	always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            waddr_o1 <= `NOPRegAddr;
            waddr_o2 <= `NOPRegAddr;
			we_o1 <= `WriteDisable;
			we_o2 <= `WriteDisable;
            wdata_o1 <= `ZeroWord;    
		    wdata_o2 <= `ZeroWord;	
            LLbit_o <= 1'b0;
            LLbit_we_o <= `WriteDisable;
            cp0_wsel_o <= 3'b000;
            cp0_we_o <= `WriteDisable;
            cp0_waddr_o <= 5'b00000;
            cp0_wdata_o <= `ZeroWord;
            inst_addr_o1 <= `ZeroWord;
            inst_addr_o2 <= `ZeroWord;
            pref_addr_o <= `ZeroWord;
        end else if (flush && flush_cause == `Exception && exception_inst_sel) begin
            waddr_o1 <= `NOPRegAddr;
            waddr_o2 <= `NOPRegAddr;
            we_o1 <= `WriteDisable;
            we_o2 <= `WriteDisable;
            wdata_o1 <= `ZeroWord;    
            wdata_o2 <= `ZeroWord;    
            LLbit_o <= 1'b0;
            LLbit_we_o <= `WriteDisable;
            cp0_wsel_o <= 3'b000;
            cp0_we_o <= `WriteDisable;
            cp0_waddr_o <= 5'b00000;
            cp0_wdata_o <= `ZeroWord;
            inst_addr_o1 <= `ZeroWord;
            inst_addr_o2 <= `ZeroWord;
            pref_addr_o <= `ZeroWord;
        end else if (flush && flush_cause == `Exception && ~exception_inst_sel) begin
            waddr_o1 <= waddr_i1;
            waddr_o2 <= `NOPRegAddr;
            we_o1 <= we_i1;
            we_o2 <= `WriteDisable;
            wdata_o1 <= wdata_i1;
            wdata_o2 <= `ZeroWord; 
            LLbit_o <= 1'b0;
            LLbit_we_o <= `WriteDisable;
            cp0_wsel_o <= 3'b000;
            cp0_we_o <= `WriteDisable;
            cp0_waddr_o <= 5'b00000;
            cp0_wdata_o <= `ZeroWord;
            inst_addr_o1 <= inst_addr_i1;
            inst_addr_o2 <= `ZeroWord;
            pref_addr_o <= pref_addr_i;
        end else if (stall[2] == `Stop && stall[3] == `NoStop) begin
            waddr_o1 <= `NOPRegAddr;
            waddr_o2 <= `NOPRegAddr;
            we_o1 <= `WriteDisable;
            we_o2 <= `WriteDisable;
            wdata_o1 <= `ZeroWord;    
            wdata_o2 <= `ZeroWord;    
            LLbit_o <= 1'b0;
            LLbit_we_o <= `WriteDisable;
            cp0_wsel_o <= 3'b000;
            cp0_we_o <= `WriteDisable;
            cp0_waddr_o <= 5'b00000;
            cp0_wdata_o <= `ZeroWord;
            inst_addr_o1 <= `ZeroWord;
            inst_addr_o2 <= `ZeroWord;
            pref_addr_o <= `ZeroWord;
		end else if (stall[2] == `NoStop) begin
            waddr_o1 <= waddr_i1;
            waddr_o2 <= waddr_i2;
            we_o1 <= we_i1;
            we_o2 <= we_i2;
            wdata_o1 <= wdata_i1;
            wdata_o2 <= wdata_i2;
            LLbit_o <= LLbit_i;
            LLbit_we_o <= LLbit_we_i;
            cp0_wsel_o <= cp0_wsel_i;
            cp0_we_o <= cp0_we_i;
            cp0_waddr_o <= cp0_waddr_i;
            cp0_wdata_o <= cp0_wdata_i;
            inst_addr_o1 <= inst_addr_i1;
            inst_addr_o2 <= inst_addr_i2;
            pref_addr_o <= pref_addr_i;
		end  //if
	end  //always
			

endmodule
