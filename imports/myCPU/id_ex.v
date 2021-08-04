`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/09 20:35:35
// Design Name: 
// Module Name: id_ex
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


module id_ex(

	input wire clk,
	input wire rst,
	input wire [3:0] stall,
	input wire flush,
	input wire flush_cause,

	// 从译码阶段传递过来的信息
	input wire [`RegBus]           id_imm,
    input wire [`BPBPacketWidth]   id_predict_pkt,
	input wire                     next_inst_in_delayslot,
	input wire [2:0]               id_cp0_sel,
	input wire [`RegAddrBus]       id_cp0_addr,
	input wire                     id_is_bly1,

	// 第一条指令的信息
	input wire [`AluOpBus]         id_aluop1,
	input wire [`AluSelBus]        id_alusel1,
//	input wire [`RegBus]           id_reg1,
//	input wire [`RegBus]           id_reg2,
	input wire [`RegAddrBus]       id_wd1,
	input wire                     id_wreg1,
	input wire                     id_is_in_delayslot1,	
    input wire [`InstAddrBus]      id_inst_addr1,
    input wire [31:0]              id_excepttype1,
	
	// 第二条指令的信息
    input wire [`AluOpBus]         id_aluop2,
    input wire [`AluSelBus]        id_alusel2,
//    input wire [`RegBus]           id_reg3,
//    input wire [`RegBus]           id_reg4,
    input wire [`RegAddrBus]       id_wd2,
    input wire                     id_wreg2,
    input wire                     id_is_in_delayslot2,
    input wire [`InstAddrBus]      id_inst_addr2,
    input wire [31:0]              id_excepttype2,
        
	// 传递到执行阶段的信息
	output reg [`RegBus]           ex_imm,
    output reg [`BPBPacketWidth]   ex_predict_pkt,
	output reg                     is_in_delayslot_o,
	output reg [2:0]               ex_cp0_sel,
	output reg [`RegAddrBus]       ex_cp0_addr,
	output reg                     ex_is_bly1,
	
	// 第一条指令的信息
	output reg [`AluOpBus]         ex_aluop1,
	output reg [`AluSelBus]        ex_alusel1,
//	output reg [`RegBus]           ex_reg1,
//	output reg [`RegBus]           ex_reg2,
	output reg [`RegAddrBus]       ex_wd1,
	output reg                     ex_wreg1,
	output reg                     ex_is_in_delayslot1,
	output reg [`InstAddrBus]      ex_inst_addr1,
	output reg [31:0]              ex_excepttype1,
	
	// 第二条指令的信息
	output reg [`AluOpBus]         ex_aluop2,
    output reg [`AluSelBus]        ex_alusel2,
//    output reg [`RegBus]           ex_reg3,
//    output reg [`RegBus]           ex_reg4,
    output reg [`RegAddrBus]       ex_wd2,
    output reg                     ex_wreg2,
    output reg                     ex_is_in_delayslot2,
    output reg [`InstAddrBus]      ex_inst_addr2,
    output reg [31:0]              ex_excepttype2
    	
);

	always @ (posedge clk) begin
		if (rst == `RstEnable) begin
			ex_aluop1 <= `EXE_NOP_OP;
			ex_aluop2 <= `EXE_NOP_OP;
			ex_alusel1 <= `EXE_RES_NOP;
			ex_alusel2 <= `EXE_RES_NOP;
//			ex_reg1 <= `ZeroWord;
//			ex_reg2 <= `ZeroWord;
//            ex_reg3 <= `ZeroWord;
//            ex_reg4 <= `ZeroWord;
			ex_wd1 <= `NOPRegAddr;
			ex_wd2 <= `NOPRegAddr;
			ex_wreg1 <= `WriteDisable;
			ex_wreg2 <= `WriteDisable;
			ex_inst_addr1 <= `ZeroWord;
			ex_inst_addr2 <= `ZeroWord;
			ex_imm <= `ZeroWord;
			ex_is_in_delayslot1 <= `NotInDelaySlot;
            ex_is_in_delayslot2 <= `NotInDelaySlot;
            is_in_delayslot_o <= `NotInDelaySlot;
            ex_predict_pkt <= {`NotBranch, `ZeroWord, `TYPE_NUL};
            ex_cp0_sel <= 3'b000;
            ex_cp0_addr <= `NOPRegAddr;
            ex_excepttype1 <= `ZeroWord;
            ex_excepttype2 <= `ZeroWord;
            ex_is_bly1 <= 1'b0;
        end else if (flush == 1'b1 && flush_cause == `Exception) begin
            ex_aluop1 <= `EXE_NOP_OP;
            ex_aluop2 <= `EXE_NOP_OP;
            ex_alusel1 <= `EXE_RES_NOP;
            ex_alusel2 <= `EXE_RES_NOP;
//            ex_reg1 <= `ZeroWord;
//            ex_reg2 <= `ZeroWord;
//            ex_reg3 <= `ZeroWord;
//            ex_reg4 <= `ZeroWord;
            ex_wd1 <= `NOPRegAddr;
            ex_wd2 <= `NOPRegAddr;
            ex_wreg1 <= `WriteDisable;
            ex_wreg2 <= `WriteDisable;
            ex_inst_addr1 <= `ZeroWord;
            ex_inst_addr2 <= `ZeroWord;
            ex_imm <= `ZeroWord;
            ex_is_in_delayslot1 <= `NotInDelaySlot;
            ex_is_in_delayslot2 <= `NotInDelaySlot;
            is_in_delayslot_o <= `NotInDelaySlot;
            ex_predict_pkt <= {`NotBranch, `ZeroWord, `TYPE_NUL};
            ex_cp0_sel <= 3'b000;
            ex_cp0_addr <= `NOPRegAddr;
            ex_excepttype1 <= `ZeroWord;
            ex_excepttype2 <= `ZeroWord;
            ex_is_bly1 <= 1'b0;
        end else if (flush == 1'b1 && flush_cause == `FailedBranchPrediction && is_in_delayslot_o == `InDelaySlot) begin  // 分支预测失败时，若第一条是延迟槽指令则置第二条无效
            ex_aluop1 <= id_aluop1;
            ex_aluop2 <= `EXE_NOP_OP;
            ex_alusel1 <= id_alusel1;
            ex_alusel2 <= `EXE_RES_NOP;
//            ex_reg1 <= id_reg1;
//            ex_reg2 <= id_reg2;
//            ex_reg3 <= `ZeroWord;
//            ex_reg4 <= `ZeroWord;
            ex_wd1 <= id_wd1;
            ex_wd2 <= `NOPRegAddr;
            ex_wreg1 <= id_wreg1;    
            ex_wreg2 <= `WriteDisable;
            ex_inst_addr1 <= id_inst_addr1;
            ex_inst_addr2 <= `ZeroWord;
            ex_imm <= id_imm;
            ex_is_in_delayslot1 <= id_is_in_delayslot1;
            ex_is_in_delayslot2 <= `NotInDelaySlot;
            is_in_delayslot_o <= next_inst_in_delayslot;
            ex_predict_pkt <= id_predict_pkt;
            ex_cp0_sel <= id_cp0_sel;
            ex_cp0_addr <= id_cp0_addr;
            ex_excepttype1 <= id_excepttype1;
            ex_excepttype2 <= `ZeroWord;
            ex_is_bly1 <= id_is_bly1;
        end else if (flush == 1'b1 && flush_cause == `FailedBranchPrediction && is_in_delayslot_o == `NotInDelaySlot) begin  // 否则置两条都无效
            ex_aluop1 <= `EXE_NOP_OP;
            ex_aluop2 <= `EXE_NOP_OP;
            ex_alusel1 <= `EXE_RES_NOP;
            ex_alusel2 <= `EXE_RES_NOP;
//            ex_reg1 <= `ZeroWord;
//            ex_reg2 <= `ZeroWord;
//            ex_reg3 <= `ZeroWord;
//            ex_reg4 <= `ZeroWord;
            ex_wd1 <= `NOPRegAddr;
            ex_wd2 <= `NOPRegAddr;
            ex_wreg1 <= `WriteDisable;
            ex_wreg2 <= `WriteDisable;
            ex_inst_addr1 <= `ZeroWord;
            ex_inst_addr2 <= `ZeroWord;
            ex_imm <= `ZeroWord;
            ex_is_in_delayslot1 <= `NotInDelaySlot;
            ex_is_in_delayslot2 <= `NotInDelaySlot;
            is_in_delayslot_o <= `NotInDelaySlot;
            ex_predict_pkt <= {`NotBranch, `ZeroWord, `TYPE_NUL};
            ex_cp0_sel <= 3'b000;
            ex_cp0_addr <= `NOPRegAddr;
            ex_excepttype1 <= `ZeroWord;
            ex_excepttype2 <= `ZeroWord;
            ex_is_bly1 <= 1'b0;
        end else if (stall[0] == `Stop && stall[1] == `NoStop) begin
            ex_aluop1 <= `EXE_NOP_OP;
            ex_aluop2 <= `EXE_NOP_OP;
            ex_alusel1 <= `EXE_RES_NOP;
            ex_alusel2 <= `EXE_RES_NOP;
//            ex_reg1 <= `ZeroWord;
//            ex_reg2 <= `ZeroWord;
//            ex_reg3 <= `ZeroWord;
//            ex_reg4 <= `ZeroWord;
            ex_wd1 <= `NOPRegAddr;
            ex_wd2 <= `NOPRegAddr;
            ex_wreg1 <= `WriteDisable;
            ex_wreg2 <= `WriteDisable;
            ex_inst_addr1 <= `ZeroWord;
            ex_inst_addr2 <= `ZeroWord;
            ex_imm <= `ZeroWord;
            ex_is_in_delayslot1 <= `NotInDelaySlot;
            ex_is_in_delayslot2 <= `NotInDelaySlot;
            is_in_delayslot_o <= is_in_delayslot_o;
            ex_predict_pkt <= {`NotBranch, `ZeroWord, `TYPE_NUL};
            ex_cp0_sel <= 3'b000;
            ex_cp0_addr <= `NOPRegAddr;
            ex_excepttype1 <= `ZeroWord;
            ex_excepttype2 <= `ZeroWord;
            ex_is_bly1 <= 1'b0;
		end else if (stall[0] == `NoStop) begin		
			ex_aluop1 <= id_aluop1;
			ex_aluop2 <= id_aluop2;
			ex_alusel1 <= id_alusel1;
			ex_alusel2 <= id_alusel2;
//			ex_reg1 <= id_reg1;
//			ex_reg2 <= id_reg2;
//            ex_reg3 <= id_reg3;
//            ex_reg4 <= id_reg4;
			ex_wd1 <= id_wd1;
			ex_wd2 <= id_wd2;
			ex_wreg1 <= id_wreg1;	
			ex_wreg2 <= id_wreg2;
            ex_inst_addr1 <= id_inst_addr1;
            ex_inst_addr2 <= id_inst_addr2;
			ex_imm <= id_imm;
            ex_is_in_delayslot1 <= id_is_in_delayslot1;
            ex_is_in_delayslot2 <= id_is_in_delayslot2;
            is_in_delayslot_o <= next_inst_in_delayslot;
            ex_predict_pkt <= id_predict_pkt;
            ex_cp0_sel <= id_cp0_sel;
            ex_cp0_addr <= id_cp0_addr;
            ex_excepttype1 <= id_excepttype1;
            ex_excepttype2 <= id_excepttype2;
            ex_is_bly1 <= id_is_bly1;
		end
	end
	
endmodule
