`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/29 16:20:18
// Design Name: 
// Module Name: branch_predict_local
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

module bpu(
    input wire clk,
    input wire rst,

    //IF阶段传入，一级预�??
    input wire [31:0] first_inst_addr1,
    input wire [31:0] first_inst_addr2,

    //IF阶段传出，一级预�??
    output wire [31:0] first_predict_inst_addr1,
    output wire [31:0] first_predict_inst_addr2,

    //Inst_buffer阶段传入，二级预�??
    input wire [31:0] second_inst_addr1,
    input wire [31:0] second_inst_addr2,
    input wire [31:0] second_inst1,
    input wire [31:0] second_inst2,
    //Inst_buffer阶段传出，二级预�??
    output reg second_branch_predict_happen1,
    output reg second_branch_predict_happen2,
    output reg [31:0] second_predict_inst_addr1,
    output reg [31:0] second_predict_inst_addr2,

    //EX阶段传入，对存储的预测结果进行修�??
    input wire [1:0] ex_branch_type,//ex阶段分支指令执行类型
    input wire ex_branch_success,
    input wire [31:0] ex_inst_addr,//被执行的分支或跳转指令地�??
    input wire [31:0] ex_next_inst_addr,//跳转后的指令地址
    input wire ex_predict_success//先前指令是否预测成功
    );
    wire [31:0] BTB_predict_inst_addr1;
    wire [31:0] BTB_predict_inst_addr2;
    wire [31:0] second_inst_offset1;
    wire [31:0] second_inst_offset2;
    wire [1:0] second_inst_type1;
    wire [1:0] second_inst_type2;

    wire BHT_local_predict1;
    wire BHT_local_predict2;

    wire BHT_gobal_predict1;
    wire BHT_gobal_predict2;


    wire [31:0] RAS_predict_inst_addr1;
    wire [31:0] RAS_predict_inst_addr2;


    wire [31:0] jr_predict_addr1;
    wire [31:0] jr_predict_addr2;

    //debug逻辑
    reg [31:0] b_cnt_total;
    reg [31:0] r_cnt_total;
    reg [31:0] local_cnt;
    reg [31:0] global_cnt;
    
    
    
    
    always @(posedge clk) begin
        if(~rst)begin
            b_cnt_total <= 32'b0;
            r_cnt_total <= 32'b0;
            local_cnt <= 32'b0;
            global_cnt <= 32'b0;
        end
        else begin
            if(ex_branch_type == `type_branch)begin
                b_cnt_total <= b_cnt_total +1;
            end
            if(ex_branch_type == `type_ret)begin
                r_cnt_total <= r_cnt_total +1;
            end
            if(second_inst_type1 == `type_branch && choice_predict1 == 1'b0 || choice_predict2 == 1'b0)begin
                local_cnt <= local_cnt + 1;
            end
            if(second_inst_type2 == `type_branch && choice_predict1 == 1'b1 || choice_predict2 == 1'b1)begin
                global_cnt <= global_cnt + 1;
            end
        end
    end
    
    pre_id_sub pre_id_sub1(
        .rst(rst),
        .inst_i(second_inst1),
        .inst_type(second_inst_type1),
//        .inst_valid(inst_valid1),
        .inst_offset(second_inst_offset1)
//        .pcr_call(inst_pcr_call1)
    );
    
     pre_id_sub pre_id_sub2(
        .rst(rst),
        .inst_i(second_inst2),
        .inst_type(second_inst_type2),
//        .inst_valid(inst_valid1),
        .inst_offset(second_inst_offset2)
//        .pcr_call(inst_pcr_call1)
    );
    
    //Branch target buffer
    BTB BTB0(
        .clk(clk),
        .rst(rst),


        //IF阶段传入
        .first_inst_addr1_i(first_inst_addr1),
        .first_inst_addr2_i(first_inst_addr2),

        //IF传出
        .first_predict_inst_addr1_o(first_predict_inst_addr1),
        .first_predict_inst_addr2_o(first_predict_inst_addr2),

        //Inst_buffer传入
        .second_inst_addr1_i(second_inst_addr1),
        .second_inst_addr2_i(second_inst_addr2),
        .second_inst_type1_i(second_inst_type1),
        .second_inst_type2_i(second_inst_type2),
        //Inst_buffer传出
        .jr_predict_addr1_o(jr_predict_addr1),
        .jr_predict_addr2_o(jr_predict_addr2),

        //EX阶段修正
        .ex_branch_success_i(ex_branch_success),
        .ex_inst_addr_i(ex_inst_addr),
        .ex_next_inst_addr_i(ex_next_inst_addr)
    );

    //branch history table
    BHT_local BHT_local0(
        .clk(clk),
        .rst(rst),

        //Inst_buffer阶段传入
        .second_inst_addr1_i(second_inst_addr1),
        .second_inst_addr2_i(second_inst_addr2),
        .second_inst_type1_i(second_inst_type1),
        .second_inst_type2_i(second_inst_type2),

        //Inst_buffer阶段传出
        .BHT_local_predict1_o(BHT_local_predict1),
        .BHT_local_predict2_o(BHT_local_predict2),

        //EX阶段传入
        .ex_branch_type_i(ex_branch_type),
        .ex_inst_addr_i(ex_inst_addr),
        .ex_branch_success_i(ex_branch_success)
    );

    BHT_global BHT_global0(
        .clk(clk),
        .rst(rst),

        //Inst_buffer阶段传入
        .second_inst_addr1_i(second_inst_addr1),
        .second_inst_addr2_i(second_inst_addr2),
        .second_inst_type1_i(second_inst_type1),
        .second_inst_type2_i(second_inst_type2),


        //Inst_buffer阶段传出
        .BHT_global_predict1_o(BHT_global_predict1),
        .BHT_global_predict2_o(BHT_global_predict2),

        //EX阶段传入
        .ex_branch_type_i(ex_branch_type),
        .ex_inst_addr_i(ex_inst_addr),
        .ex_branch_success_i(ex_branch_success)
    );

    GL_choice GL_choice0(
        .clk(clk),
        .rst(rst),

        //Inst_buffer阶段传入
        .second_inst_addr1_i(second_inst_addr1),
        .second_inst_addr2_i(second_inst_addr2),

        //Inst_buffer阶段传出
        .choice_predict1_o(choice_predict1),
        .choice_predict2_o(choice_predict2),

        //EX阶段传入
        .ex_branch_type_i(ex_branch_type),
        .ex_inst_addr_i(ex_inst_addr),
        .ex_predict_success_i(ex_predict_success)
    );

    always @(*) begin
        case(second_inst_type1)
            `type_branch:begin
                if(choice_predict1 == 1'b0)begin
                    if(BHT_local_predict1 == 1'b1)begin
                        second_predict_inst_addr1 = second_inst_addr1 + second_inst_offset1 + 32'h4;
                        second_branch_predict_happen1 = 1'b1;
                    end
                    else begin
                        second_predict_inst_addr1 = second_inst_addr1 + 32'h8;
                        second_branch_predict_happen1 = 1'b0;
                    end
                end
                else begin
                    if(BHT_global_predict1 == 1'b1)begin
                        second_predict_inst_addr1 = second_inst_addr1 + second_inst_offset1 + 32'h4;
                        second_branch_predict_happen1 = 1'b1;
                    end
                    else begin
                        second_predict_inst_addr1 = second_inst_addr1 + 32'h8;
                        second_branch_predict_happen1 = 1'b0;
                    end
                end
            end
            `type_ret:begin
                second_predict_inst_addr1 = jr_predict_addr1;
                second_branch_predict_happen1 = 1'b1;
            end
            `type_j:begin
//                if (second_inst_pcr_call1) begin
//                    second_predict_inst_addr1 = second_inst_addr1 + second_inst_offset1 + 4;
//                    second_branch_predict_happen1 = 1'b1;
//                end else begin
                    second_predict_inst_addr1 = {second_inst_addr1[31:28],second_inst_offset1[27:0]};
                    second_branch_predict_happen1 = 1'b1;
//                end
            end
            `type_no:begin
                second_predict_inst_addr1 = 32'b0;
                second_branch_predict_happen1 = 1'b0;
            end
            default:begin
                second_predict_inst_addr1 = 32'b0;
                second_branch_predict_happen1 = 1'b0;
            end
        endcase
    end

    always @(*) begin
        case(second_inst_type2)
            `type_branch:begin
                if(choice_predict2 == 1'b0)begin
                    if(BHT_local_predict2 == 1'b1)begin
                        second_predict_inst_addr2 = second_inst_addr2 + second_inst_offset2 + 32'h4;
                        second_branch_predict_happen2 = 1'b1;
                    end
                    else begin
                        second_predict_inst_addr2 = second_inst_addr2 + 32'h8;
                        second_branch_predict_happen2 = 1'b0;
                    end
                end
                else begin
                    if(BHT_global_predict2 == 1'b1)begin
                        second_predict_inst_addr2 = second_inst_addr2 + second_inst_offset2 + 32'h4;
                        second_branch_predict_happen2 = 1'b1;
                    end
                    else begin
                        second_predict_inst_addr2 = second_inst_addr2 + 32'h8;
                        second_branch_predict_happen2 = 1'b0;
                    end
                end
            end
            `type_ret:begin
                second_predict_inst_addr2 = jr_predict_addr2;
                second_branch_predict_happen2 = 1'b1;
            end
            `type_j:begin
//                if (second_inst_pcr_call2) begin
//                    second_predict_inst_addr2 = second_inst_addr2 + second_inst_offset2 + 4;
//                    second_branch_predict_happen2 = 1'b1;
//                end else begin
                    second_predict_inst_addr2 = {second_inst_addr2[31:28],second_inst_offset2[27:0]};
                    second_branch_predict_happen2 = 1'b1;
//                end
            end
            `type_no:begin
                second_predict_inst_addr2 = 32'b0;
                second_branch_predict_happen2 = 1'b0;
            end
            default:begin
                second_predict_inst_addr2 = 32'b0;
                second_branch_predict_happen2 = 1'b0;
            end
        endcase
    end
endmodule
