`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/09 14:36:21
// Design Name: 
// Module Name: pc_reg
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

module pc_reg(
	input wire clk,
	input wire resetn,	
	input wire flush,
	input wire flush_cause,
	input wire [`InstAddrBus] epc,
	input wire instbuffer_full,
	input wire [`InstAddrBus] icache_npc,
	
	// 与转移指令有关的信息
	input wire branch_flag_i,
	input wire [`RegBus] branch_target_address_i,
    input wire [`InstAddrBus] ex_inst_addr,

	output reg [`InstAddrBus] pc,
	output reg icache_rreq_o
	
);

    reg [`InstAddrBus] npc;
	
	always @(*) begin
        if (resetn == `RstEnable) npc = 32'hbfc00000;
        else if (flush == 1'b1 && flush_cause == `Exception) npc = epc;
        else if (flush == 1'b1 && flush_cause == `FailedBranchPrediction && branch_flag_i == `Branch) npc = branch_target_address_i;
        else if (flush == 1'b1 && flush_cause == `FailedBranchPrediction && branch_flag_i == `NotBranch) npc = ex_inst_addr + 32'h8;
        else if (instbuffer_full) npc = pc;
        else npc = icache_npc;
    end
	
	always @(posedge clk)  pc <= npc;
	
	always @ (*) begin
        if (~resetn | flush | instbuffer_full)
            icache_rreq_o = `ReadDisable;
        else
            icache_rreq_o = `ReadEnable;
    end

endmodule
