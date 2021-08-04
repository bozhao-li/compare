`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/09 21:21:11
// Design Name: 
// Module Name: ex_mem
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


module ex_mem(

	input wire clk,
	input wire rst,
	input wire flush,
	input wire flush_cause,
	input wire [3:0] stall,
	
	// 来自执行阶段的信息
	input wire ex_LLbit,
	input wire ex_LLbit_we,
	input wire [`DoubleRegBus] hilo_i,
	input wire [1:0] cnt_i,
	
	// 与访存指令有关的变量
	input wire [`AluOpBus] ex_aluop1,
	input wire [`RegBus] ex_mem_addr,
	input wire [`RegBus] ex_reg2,
	
	// 与特权指令有关的信息
	input wire [2:0] ex_cp0_wsel,
	input wire ex_cp0_we,
	input wire [4:0] ex_cp0_waddr,
	input wire [`RegBus] ex_cp0_wdata,
	
	// 第一条指令的信息	
	input wire [`RegAddrBus] ex_wd1,
	input wire ex_wreg1,
	input wire [`RegBus] ex_wdata1,
	input wire [31:0] ex_excepttype1,
	input wire ex_is_in_delayslot1, 
	input wire [`InstAddrBus] ex_inst_addr1,	
	
    // 第二条指令的信息	
    input wire [`RegAddrBus] ex_wd2,
    input wire ex_wreg2,
    input wire [`RegBus] ex_wdata2,
    input wire [31:0] ex_excepttype2,
    input wire ex_is_in_delayslot2,
    input wire [`InstAddrBus] ex_inst_addr2,	
    
	// 送到访存阶段的信息
	output reg mem_LLbit,
	output reg mem_LLbit_we,
	output reg [`DoubleRegBus] hilo_o,
	output reg [1:0] cnt_o,
	
    // 与访存指令有关的变量
    output reg [`AluOpBus] mem_aluop1,
    output reg [`RegBus] mem_mem_addr,
    output reg [`RegBus] mem_reg2,
    
    // 与特权指令有关的信息
    output reg [2:0] mem_cp0_wsel,
    output reg mem_cp0_we,
    output reg [4:0] mem_cp0_waddr,
    output reg [`RegBus] mem_cp0_wdata,
    
	// 第一条指令的信息
	output reg [`RegAddrBus] mem_wd1,
	output reg  mem_wreg1,
	output reg [`RegBus] mem_wdata1,
	output reg [31:0] mem_excepttype1,
	output reg mem_is_in_delayslot1,
	output reg [`InstAddrBus] mem_inst_addr1,	
	
    // 第二条指令的信息
    output reg [`RegAddrBus] mem_wd2,
    output reg  mem_wreg2,
    output reg [`RegBus] mem_wdata2,
    output reg [31:0] mem_excepttype2,
    output reg mem_is_in_delayslot2,
    output reg [`InstAddrBus] mem_inst_addr2

);

    always @ (posedge clk) begin
		if(rst == `RstEnable) begin
			mem_wd1 <= `NOPRegAddr;
			mem_wd2 <= `NOPRegAddr;
			mem_wreg1 <= `WriteDisable;
			mem_wreg2 <= `WriteDisable;
            mem_wdata1 <= `ZeroWord;	
            mem_wdata2 <= `ZeroWord;
            mem_aluop1 <= `EXE_NOP_OP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;
            mem_LLbit <= 1'b0;
            mem_LLbit_we <= `WriteDisable;
            mem_cp0_wsel <= 3'b000;
            mem_cp0_we <= `WriteDisable;
            mem_cp0_waddr <= 5'b00000;
            mem_cp0_wdata <= `ZeroWord;
            mem_inst_addr1 <= `ZeroWord;
            mem_inst_addr2 <= `ZeroWord;
            mem_excepttype1 <= `ZeroWord;
            mem_excepttype2 <= `ZeroWord;
            mem_is_in_delayslot1 <= `NotInDelaySlot;
            mem_is_in_delayslot2 <= `NotInDelaySlot;
            hilo_o <= {`ZeroWord, `ZeroWord};
            cnt_o <= 2'b00;
        end else if (flush == 1'b1 && flush_cause == `Exception) begin
            mem_wd1 <= `NOPRegAddr;
            mem_wd2 <= `NOPRegAddr;
            mem_wreg1 <= `WriteDisable;
            mem_wreg2 <= `WriteDisable;
            mem_wdata1 <= `ZeroWord;    
            mem_wdata2 <= `ZeroWord;   
            mem_aluop1 <= `EXE_NOP_OP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;
            mem_LLbit <= 1'b0;
            mem_LLbit_we <= `WriteDisable;
            mem_cp0_wsel <= 3'b000;
            mem_cp0_we <= `WriteDisable;
            mem_cp0_waddr <= 5'b00000;
            mem_cp0_wdata <= `ZeroWord;
            mem_inst_addr1 <= `ZeroWord;
            mem_inst_addr2 <= `ZeroWord;
            mem_excepttype1 <= `ZeroWord;
            mem_excepttype2 <= `ZeroWord;
            mem_is_in_delayslot1 <= `NotInDelaySlot;
            mem_is_in_delayslot2 <= `NotInDelaySlot;
            hilo_o <= {`ZeroWord, `ZeroWord};
            cnt_o <= 2'b00;
        end else if (stall[1] == `Stop && stall[2] == `NoStop) begin
            mem_wd1 <= `NOPRegAddr;
            mem_wd2 <= `NOPRegAddr;
            mem_wreg1 <= `WriteDisable;
            mem_wreg2 <= `WriteDisable;
            mem_wdata1 <= `ZeroWord;    
            mem_wdata2 <= `ZeroWord;
            mem_aluop1 <= `EXE_NOP_OP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;
            mem_LLbit <= 1'b0;
            mem_LLbit_we <= `WriteDisable;
            mem_cp0_wsel <= 3'b000;
            mem_cp0_we <= `WriteDisable;
            mem_cp0_waddr <= 5'b00000;
            mem_cp0_wdata <= `ZeroWord;
            mem_inst_addr1 <= `ZeroWord;
            mem_inst_addr2 <= `ZeroWord;
            mem_excepttype1 <= `ZeroWord;
            mem_excepttype2 <= `ZeroWord;
            mem_is_in_delayslot1 <= `NotInDelaySlot;
            mem_is_in_delayslot2 <= `NotInDelaySlot;
            hilo_o <= {`ZeroWord, `ZeroWord};
            cnt_o <= 2'b00;
		end else if (stall[1] == `NoStop) begin
			mem_wd1 <= ex_wd1;
			mem_wd2 <= ex_wd2;
			mem_wreg1 <= ex_wreg1;
			mem_wreg2 <= ex_wreg2;
			mem_wdata1 <= ex_wdata1;
			mem_wdata2 <= ex_wdata2;	
            mem_aluop1 <= ex_aluop1;
            mem_mem_addr <= ex_mem_addr;
            mem_reg2 <= ex_reg2;	
            mem_LLbit <= ex_LLbit;
            mem_LLbit_we <= ex_LLbit_we;
            mem_cp0_wsel <= ex_cp0_wsel;
            mem_cp0_we <= ex_cp0_we;
            mem_cp0_waddr <= ex_cp0_waddr;
            mem_cp0_wdata <= ex_cp0_wdata;
            mem_inst_addr1 <= ex_inst_addr1;
            mem_inst_addr2 <= ex_inst_addr2;
            mem_excepttype1 <= ex_excepttype1;
            mem_excepttype2 <= ex_excepttype2;
            mem_is_in_delayslot1 <= ex_is_in_delayslot1;
            mem_is_in_delayslot2 <= ex_is_in_delayslot2;
            hilo_o <= hilo_i;
            cnt_o <= cnt_i;
		end  //if
	end  //always
			
endmodule
