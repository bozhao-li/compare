`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/30 16:04:07
// Design Name: 
// Module Name: RAS
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

module RAS(
    input wire clk,
    input wire rst,

    input wire [1:0] second_inst_type1_i,
    input wire [1:0] second_inst_type2_i,

    input wire [1:0] ex_branch_type_i,
    input wire ex_set_register,
    input wire [31:0] ex_inst_addr_i,//待会要加8

    output reg [31:0] RAS_predict_inst_addr1_o,
    output reg [31:0] RAS_predict_inst_addr2_o
    );
    reg [31:0] ra_stack[7:0];
    reg [2:0] stack_point_current;

    always @(*) begin
        if(~rst)begin
            RAS_predict_inst_addr1_o = 32'b0;
            RAS_predict_inst_addr2_o = 32'b0;
        end
        else if(second_inst_type1_i == `type_ret)begin
            RAS_predict_inst_addr1_o = ra_stack[stack_point_current];
            RAS_predict_inst_addr2_o = 32'b0;
        end
        else if(second_inst_type2_i == `type_ret)begin
            RAS_predict_inst_addr2_o = ra_stack[stack_point_current];
            RAS_predict_inst_addr1_o = 32'b0;
        end
        else begin
            RAS_predict_inst_addr1_o = 32'b0;
            RAS_predict_inst_addr2_o = 32'b0;
        end
    end

    always @(posedge clk) begin
        if(~rst)begin
            begin:stack_initail
                integer i;
                for (i = 0;i < 8 ;i = i + 1 ) begin
                    ra_stack[i] <= 32'b0;
                end
            end
            stack_point_current <= 3'b0;
        end
        else if(second_inst_type1_i == `type_ret || second_inst_type2_i == `type_ret)begin
             if(ex_set_register && ex_branch_type_i != `type_no)begin
                ra_stack[stack_point_current] <= ex_inst_addr_i + 8;
             end
             else begin
                stack_point_current <= stack_point_current - 1'b1;
             end
        end
        else if(ex_set_register && ex_branch_type_i != `type_no)begin
            ra_stack[stack_point_current + 1'b1] <= ex_inst_addr_i + 8;
            stack_point_current <= stack_point_current + 1'b1;
        end
        else begin
            stack_point_current <= stack_point_current;
        end
    end
endmodule
