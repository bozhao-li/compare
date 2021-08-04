`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/30 13:55:01
// Design Name: 
// Module Name: BHT
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

module BHT_local(
    input wire clk,
    input wire rst,
    
    //inst_buffer阶段传入，二级预�??
    input wire [31:0] second_inst_addr1_i,
    input wire [31:0] second_inst_addr2_i,
    input wire [1:0] second_inst_type1_i,
    input wire [1:0] second_inst_type2_i,

    //ex阶段传入，修�??
    input wire [1:0] ex_branch_type_i,
    input wire [31:0] ex_inst_addr_i,
    input wire ex_branch_success_i,

    //inst_buffer阶段传出，二级预�??
    output reg BHT_local_predict1_o,
    output reg BHT_local_predict2_o
    );

    wire [7:0] inst_index1 ;
    wire [7:0] inst_index2 ;
    wire [9:0] pht_index1;
    wire [9:0] pht_index2;
    wire [7:0] corr_index;
    wire [9:0] pht_corr_index;


    reg [3:0] branch_history_record [255:0];
    reg [1:0] pht[1023:0];
    reg [255:0] bhr_valid;
    reg [1023:0] pht_valid;

    assign inst_index1 = second_inst_addr1_i[9:2];
    assign inst_index2 = second_inst_addr2_i[9:2];
    assign pht_index1 = bhr_valid[inst_index1] ? {branch_history_record[inst_index1],second_inst_addr1_i[7:2]} : 
                                                  {4'b0000^second_inst_addr1_i[9:6],second_inst_addr1_i[7:2]};
    assign pht_index2 =  bhr_valid[inst_index2] ? {branch_history_record[inst_index2],second_inst_addr2_i[7:2]} : 
                                                  {4'b0000^second_inst_addr2_i[9:6],second_inst_addr2_i[7:2]};

    assign corr_index = ex_inst_addr_i[9:2];
    assign pht_corr_index =  bhr_valid[corr_index] ? {branch_history_record[corr_index],ex_inst_addr_i[7:2]} : 
                                                  {4'b0000^ex_inst_addr_i[9:6],ex_inst_addr_i[7:2]};


    always @(*) begin
        if(bhr_valid[inst_index1] == 1'b1 && pht_valid[pht_index1] == 1'b1)begin
            BHT_local_predict1_o = pht[pht_index1][1:1];
        end
        else begin
            BHT_local_predict1_o = 1'b0;
        end
    end

    always @(*) begin
        if(bhr_valid[inst_index2] == 1'b1 && pht_valid[pht_index2] == 1'b1)begin
            BHT_local_predict2_o = pht[pht_index2][1:1];
        end
        else begin
            BHT_local_predict2_o = 1'b0;
        end
    end
    
    reg rst_1, rst_2;
    always @(posedge clk) begin
        rst_1 <= rst;
        rst_2 <= rst;
    end

    //修正
    always @(posedge clk) begin
        if(~rst)begin
            bhr_valid <= 256'b0;
            pht_valid <= 1024'b0;
        end
        else if(ex_branch_type_i == `type_branch)begin
            bhr_valid[corr_index] <= 1'b1;
            pht_valid[pht_corr_index] <= 1'b1;
            if(ex_branch_success_i)begin
                if(bhr_valid[corr_index] == 1'b1)begin
                    branch_history_record[corr_index] <= {branch_history_record[corr_index][2:0],1'b1};
                end
                else begin
                    branch_history_record[corr_index] <= {3'b0,1'b1};
                end
                case (pht[pht_corr_index])
                    `SNT:   pht[pht_corr_index] <= `WNT;
                    `WNT:   pht[pht_corr_index] <=  `WT;
                    `WT:    pht[pht_corr_index] <=  `ST;
                    `ST:    pht[pht_corr_index] <=  `ST;
                    default:    pht[pht_corr_index] = `WNT;  // 初始状�?�设置为weakly taken
                endcase
            end
            else begin
                if(bhr_valid[corr_index] == 1'b1)begin
                    branch_history_record[corr_index] <= {branch_history_record[corr_index][2:0],1'b0};
                end
                else begin
                    branch_history_record[corr_index] <= {3'b0,1'b0};
                end
                case (pht[pht_corr_index])
                    `SNT:   pht[pht_corr_index] <= `SNT;
                    `WNT:   pht[pht_corr_index] <=  `SNT;
                    `WT:    pht[pht_corr_index] <=  `WNT;
                    `ST:    pht[pht_corr_index] <=  `WT;
                    default:    pht[pht_corr_index] = `WNT;  // 初始状�?�设置为weakly taken
                endcase
            end
        end
    end
endmodule
