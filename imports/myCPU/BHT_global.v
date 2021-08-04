`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/30 22:05:01
// Design Name: 
// Module Name: BHT_gobal
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
`define type_branch 2'b01
`define type_ret 2'b10
`define type_j 2'b11
`define type_no 2'b00
`define SNT 2'b00
`define WNT 2'b01 
`define WT 2'b10 
`define ST 2'b11

module BHT_global(
    input wire clk,
    input wire rst,

    //inst_buffer阶段传入，二级预�?
    input wire [31:0] second_inst_addr1_i,
    input wire [31:0] second_inst_addr2_i,
    input wire [1:0]  second_inst_type1_i,
    input wire [1:0]  second_inst_type2_i,

    //inst_buffer阶段传出，二级预�?
    output reg BHT_global_predict1_o,
    output reg BHT_global_predict2_o,

    //EX阶段传入，对存储的预测结果进行修�?
    input wire [1:0] ex_branch_type_i,//ex阶段分支指令执行类型
    input wire ex_branch_success_i,
    input wire [31:0] ex_inst_addr_i//被执行的分支或跳转指令地�?
    );
    reg [8:0] GHR;
    reg [1:0] PHT [511:0];//pattern history table,二位饱和计数器单�?
    reg [511:0] PHT_valid;
    wire [8:0] index1;//指令1对应的计数器单元地址
    wire [8:0] index2;
    wire [8:0] corr_index;

    assign index1 = {GHR^second_inst_addr1_i[10:2]};
    assign index2 = {GHR^second_inst_addr2_i[10:2]};
    assign corr_index = {GHR^ex_inst_addr_i[10:2]};

    //全局预测
    always @(*) begin
        if(PHT_valid[index1] == 1'b1)begin
            BHT_global_predict1_o <= PHT[index1][1:1];
            BHT_global_predict2_o <= PHT[index2][1:1];
        end
        else begin
            BHT_global_predict1_o <= 1'b0;
            BHT_global_predict2_o <= 1'b0;
        end
    end

    //修正
    always @(posedge clk) begin
        if(~rst)begin
            PHT_valid <= 512'b0;
            GHR <= 9'b0;
        end
        else if(ex_branch_type_i == `type_branch)begin
            PHT_valid[corr_index] <= 1'b1;
            if(ex_branch_success_i)begin
                GHR <= {GHR[7:0],1'b1};
                case(PHT[corr_index])
                    `SNT:   PHT[corr_index] <= `WNT;
                    `WNT:   PHT[corr_index] <=  `WT;
                    `WT:    PHT[corr_index] <=  `ST;
                    `ST:    PHT[corr_index] <=  `ST;
                    default:    PHT[corr_index] = `WNT; 
                endcase
            end
            else begin
                GHR <= {GHR[7:0],1'b0};
                case (PHT[corr_index])
                    `SNT:   PHT[corr_index] <= `SNT;
                    `WNT:   PHT[corr_index] <=  `SNT;
                    `WT:    PHT[corr_index] <=  `WNT;
                    `ST:    PHT[corr_index] <=  `WT;
                    default:    PHT[corr_index] = `WNT;  // 初始状�?�设置为weakly taken
                endcase
            end
        end
    end
endmodule
