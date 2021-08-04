`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/29 17:27:11
// Design Name: 
// Module Name: BTB
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

module BTB(
    input wire clk,
    input wire rst,

    input wire [31:0] first_inst_addr1_i,
    input wire [31:0] first_inst_addr2_i,

    input wire [31:0] ex_inst_addr_i,
    input wire ex_branch_success_i,
    input wire [31:0] ex_next_inst_addr_i,

    input wire [31:0] second_inst_addr1_i,
    input wire [31:0] second_inst_addr2_i,
    input wire [1:0]  second_inst_type1_i,
    input wire [1:0]  second_inst_type2_i,

    output reg [31:0] jr_predict_addr1_o,
    output reg [31:0] jr_predict_addr2_o,

    output reg [31:0] first_predict_inst_addr1_o,
    output reg [31:0] first_predict_inst_addr2_o
    );
    reg [31:0]  BTB_tag [511:0];
    reg [31:0]  BTB_next_inst_addr[511:0];
    reg [511:0] BTB_valid;

    wire [8:0]  BTB_index1;
    wire [8:0]  BTB_index2;
    wire [31:0] BTB_tag1;
    wire [31:0] BTB_tag2;

    wire [8:0]  BTB_jr_index1;
    wire [8:0]  BTB_jr_index2;
    wire [31:0] BTB_jr_tag1;
    wire [31:0] BTB_jr_tag2;

    wire [8:0]  BTB_corr_index;
    wire [31:0] BTB_corr_tag;

    assign BTB_index1 =     first_inst_addr1_i[10:2];
    assign BTB_index2 =     first_inst_addr2_i[10:2];
    assign BTB_corr_index = ex_inst_addr_i[10:2];
    assign BTB_tag1 =     first_inst_addr1_i;
    assign BTB_tag2 =     first_inst_addr2_i;
    assign BTB_corr_tag =   ex_inst_addr_i;


    assign BTB_jr_index1 =     second_inst_addr1_i[10:2];
    assign BTB_jr_index2 =     second_inst_addr2_i[10:2];
    assign BTB_jr_tag1 =     second_inst_addr1_i;
    assign BTB_jr_tag2 =     second_inst_addr2_i;

    //分支指令1查询，查询成功输出跳转地�?，不成功输出0
    always @(*) begin
        if(BTB_valid[BTB_index1] == 1'b1 && BTB_tag[BTB_index1] == BTB_tag1)begin
            first_predict_inst_addr1_o = BTB_next_inst_addr[BTB_index1];
        end
        else begin
            first_predict_inst_addr1_o = 32'b0;
        end
    end

    //分支指令2查询
    always @(*) begin
        if(BTB_valid[BTB_index2] == 1'b1 && BTB_tag[BTB_index2] == BTB_tag2)begin
            first_predict_inst_addr2_o = BTB_next_inst_addr[BTB_index2];
        end
        else begin
            first_predict_inst_addr2_o = 32'b0;
        end
    end

    //jr指令查询
    always @(*) begin
        if(BTB_valid[BTB_jr_index1] == 1'b1 && BTB_tag[BTB_jr_index1] == BTB_jr_tag1)begin
            jr_predict_addr1_o = BTB_next_inst_addr[BTB_jr_index1];
        end
        else begin
            jr_predict_addr1_o = 32'b0;
        end
    end

    always @(*) begin
        if(BTB_valid[BTB_jr_index2] == 1'b1 && BTB_tag[BTB_jr_index2] == BTB_jr_tag2)begin
            jr_predict_addr2_o = BTB_next_inst_addr[BTB_jr_index2];
        end
        else begin
            jr_predict_addr2_o = 32'b0;
        end
    end

    //分支内容更正
    always @(posedge clk) begin
        if(~rst)begin
            BTB_valid <= 512'b0;
        end
        else if(ex_branch_success_i)begin
            if(BTB_valid[BTB_corr_index] == 1'b0)begin
                BTB_tag[BTB_corr_index] <= BTB_corr_tag;
                BTB_next_inst_addr[BTB_corr_index] <= ex_next_inst_addr_i;
                BTB_valid[BTB_corr_index] <= 1'b1;
            end
            else begin
                BTB_tag[BTB_corr_index] <= BTB_corr_tag;
                BTB_next_inst_addr[BTB_corr_index] <= ex_next_inst_addr_i;
            end
        end
        else begin
            
        end
    end
endmodule
