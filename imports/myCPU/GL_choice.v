`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/01 16:10:35
// Design Name: 
// Module Name: GL_choice
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
`define SL 2'b00
`define WL 2'b01
`define WG 2'b10
`define SG 2'b11
`define type_branch 2'b01
`define type_ret 2'b10
`define type_j 2'b11
`define type_no 2'b00

module GL_choice(
    input wire clk,
    input wire rst,
    
    input wire [31:0] second_inst_addr1_i,
    input wire [31:0] second_inst_addr2_i,

    input wire [1:0] ex_branch_type_i,
    input wire [31:0] ex_inst_addr_i,
    input wire ex_predict_success_i,

    output reg choice_predict1_o,
    output reg choice_predict2_o
    );
    reg [1:0] CPHT [255:0];
    reg [255:0] CPHT_valid;
    wire [7:0] inst_index1;
    wire [7:0] inst_index2; 
    wire [7:0] cor_index;
    assign inst_index1 = second_inst_addr1_i[10:3];
    assign inst_index2 = second_inst_addr2_i[10:3];
    assign corr_index = ex_inst_addr_i[10:3];
    
    /*always@(*)begin
        if(~rst)begin
            choice_predict1_o = 1'b0;
            choice_predict2_o = 1'b0;
        end
        else begin
            choice_predict1_o = 1'b0;
            choice_predict2_o = 1'b0;
        end
    end*/
    //预测选择�?0选择�?部预测，1选择全局预测
    always @(*) begin
        if(CPHT_valid[inst_index1] == 1'b1)begin
            choice_predict1_o <= CPHT[inst_index1][1:1];
        end
        else begin
            choice_predict1_o <= 1'b0;
        end

        if(CPHT_valid[inst_index2] == 1'b1)begin
            choice_predict2_o <= CPHT[inst_index2][1:1];
        end
        else begin
            choice_predict2_o <= 1'b0;
        end
    end

    //修正
    always @(posedge clk) begin
        if(~rst)begin
            CPHT_valid <= 256'b0;
        end
        else if(ex_branch_type_i == `type_branch && ex_predict_success_i)begin
            CPHT_valid[corr_index] <= 1'b1;
            case(CPHT[corr_index])
                    `SL:   CPHT[corr_index] <= `SL;
                    `WL:   CPHT[corr_index] <=  `SL;
                    `WG:    CPHT[corr_index] <=  `SG;
                    `SG:    CPHT[corr_index] <=  `SG;
                    default:    CPHT[corr_index] <= `WL;
            endcase
        end
        else if(ex_branch_type_i == `type_branch && ~ex_predict_success_i)begin
            CPHT_valid[corr_index] <= 1'b1;
            case(CPHT[corr_index])
                    `SL:   CPHT[corr_index] <= `WL;
                    `WL:   CPHT[corr_index] <=  `WG;
                    `WG:    CPHT[corr_index] <=  `WL;
                    `SG:    CPHT[corr_index] <=  `WG;
                    default:    CPHT[corr_index] <= `WL;
            endcase
        end
    end
endmodule
