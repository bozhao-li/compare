`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/11 22:51:56
// Design Name: 
// Module Name: instbuffer
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
module instbuffer(

    input wire clk,
    input wire rst,
    input wire flush,
    input wire issue_mode,
    input wire issue_i,
    
//    input wire is_jb1,
    
    input wire [`InstBus] inst_i1,
    input wire [`InstBus] inst_i2,
    input wire [`InstAddrBus] inst_addr_i1,
    input wire [`InstAddrBus] inst_addr_i2,
    input wire inst_valid1,
    input wire inst_valid2,
    input wire [`BPBPacketWidth] predict_pkt1,
    input wire [`BPBPacketWidth] predict_pkt2,
    
    output wire [`InstBus] issue_inst1,
    output wire [`InstBus] issue_inst2,
    output wire [`InstAddrBus] issue_inst_addr1,
    output wire [`InstAddrBus] issue_inst_addr2,
    output wire [`BPBPacketWidth] issue_predict_pkt,
    
    output wire issue_en1,
//    output wire issue_en2,
    output wire instbuffer_full
//    output wire stallreq_from_delayslot
    
//    output wire [1:0] inst_type1,
//    output wire [31:0] inst_offset1,
//    output wire inst_pcr_call1,
    
//    output wire [1:0] inst_type2,
//    output wire [31:0] inst_offset2,
//    output wire inst_pcr_call2
    
    );
    
    // InstBuffer，用于存储每条指令的内容和地址
    reg [`InstBus] fifo_data [`InstBufferSize-1:0];
    reg [`InstAddrBus] fifo_addr [`InstBufferSize-1:0];
    reg [`BPBPacketWidth] fifo_predict_pkt [`InstBufferSize-1:0];
    
    reg [`InstBufferSizeLog2-1:0] tail;  // 下一条要入队的指令的位置
    reg [`InstBufferSizeLog2-1:0] head;  // 下一条要出队的指令的位置
    reg [`InstBufferSize-1:0] valid;  // 指令是否有效
    reg instbuffer_full_dly;
    
    always @ (posedge clk) begin
        // 指令出队列即使指令无效
        if (rst == `RstEnable || flush == 1'b1) begin
            head <= 5'h0;
            valid <= 32'h0;
//        end else if (stallreq_from_delayslot) begin
//            head <= head;            
        end else if (issue_i == `Valid && issue_mode == `SingleIssue) begin
            valid[head] <= `Invalid;
            head <= head + 1;
        end else if (issue_i == `Valid && issue_mode == `DualIssue) begin
            valid[head] <= `Invalid;
            valid[head + 5'h1] <= `Invalid;
            head <= head + 2;
        end
        // 指令入队列即使指令有效
        if (rst == `RstEnable || flush == 1'b1) begin
            tail <= 5'h0;
//        end else if (instbuffer_full_dly == 1'b1) begin
//            tail <= tail;
        end else if (inst_valid1 == `Valid && inst_valid2 == `Invalid) begin
            valid[tail] <= 1'b1;
            tail <= tail + 1;
        end else if (inst_valid1 == `Valid && inst_valid2 == `Valid) begin
            valid[tail] <= 1'b1;
            valid[tail + 5'h1] <= 1'b1;
            tail <= tail + 2;
        end
    end
    
    // 写指令到InstBuffer中      
    always @ (posedge clk) begin
        fifo_data[tail] <= inst_i1;
        fifo_data[tail + 5'h1] <= inst_i2;
        fifo_addr[tail] <= inst_addr_i1;
        fifo_addr[tail + 5'h1] <= inst_addr_i2;
        fifo_predict_pkt[tail] <= predict_pkt1;
        fifo_predict_pkt[tail + 5'h1] <= predict_pkt2;
    end
    
//    always @ (posedge clk) begin
//        if (rst == `RstEnable || flush == 1'b1) begin
//            instbuffer_full <= 1'b0;
//            instbuffer_full_dly <= 1'b0;
//        end else begin
//            instbuffer_full <= valid[tail+5'h7];
//            instbuffer_full_dly <= instbuffer_full;
//        end
//    end
            
//    assign issue_inst1 = valid[head] ? fifo_data[head] : `ZeroWord;
//    assign issue_inst2 = valid[head + 5'h1] ? fifo_data[head + 5'h1] : `ZeroWord;
//    assign issue_inst_addr1 = valid[head] ? fifo_addr[head] : `ZeroWord;
//    assign issue_inst_addr2 = valid[head + 5'h1] ? fifo_addr[head + 5'h1] : `ZeroWord;
//    assign issue_predict_pkt = valid[head] ? fifo_predict_pkt[head] : 35'b0;  // 分支指令必定为指令1，只传指令1的即可
    assign issue_inst1 = fifo_data[head];
    assign issue_inst2 = fifo_data[head + 5'h1];
    assign issue_inst_addr1 = fifo_addr[head];
    assign issue_inst_addr2 = fifo_addr[head + 5'h1];
    assign issue_predict_pkt = fifo_predict_pkt[head];  // 分支指令必定为指令1，只传指令1的即可
    assign issue_en1 = valid[head + 5'h2];  // 如果head指针所指的位置有指令，则允许发射
    assign instbuffer_full = valid[tail + 5'h7];
//    assign issue_en2 = valid[head + 5'h1];
//    assign stallreq_from_delayslot = ~valid[head + 5'h1] & is_jb1 & ~inst_valid1;
    
endmodule
