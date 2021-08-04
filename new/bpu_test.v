`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/24 11:26:29
// Design Name: 
// Module Name: bpu_test
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


module bpu_test(
    input wire clk,
    input wire resetn,
    
	input wire [`AluOpBus] aluop_i,
	input wire stallreq_from_ex,
	input wire stallreq_from_dcache,
	input wire predict_flag,
	input wire [1:0] wrong_type,
	
	output reg [31:0] jb_cnt,
	output reg [31:0] wrong_cnt,
	output reg [31:0] j_cnt,
	output reg [31:0] b_cnt,
	output reg [31:0] r_cnt
    );
    
    always @(posedge clk) begin
        if (~resetn) begin
            jb_cnt <= 32'b0;
        end else if (stallreq_from_ex | stallreq_from_dcache) begin
            jb_cnt <= jb_cnt;
        end else begin
            case (aluop_i)
                `EXE_J_OP,`EXE_JAL_OP,`EXE_JR_OP,`EXE_JALR_OP,`EXE_BEQ_OP,    
                `EXE_BGTZ_OP,`EXE_BLEZ_OP,`EXE_BNE_OP,`EXE_BGEZ_OP,`EXE_BGEZAL_OP,
                `EXE_BLTZ_OP,`EXE_BLTZAL_OP:    jb_cnt <= jb_cnt + 32'd1;
                default:                        jb_cnt <= jb_cnt;
            endcase  // case aluop_i
        end
    end
    
    always @(posedge clk) begin
        if (~resetn) begin
            wrong_cnt <= 32'b0;
        end else if (stallreq_from_ex | stallreq_from_dcache) begin
            wrong_cnt <= wrong_cnt;
        end else if (~predict_flag) begin
            wrong_cnt <= wrong_cnt + 32'h1;
        end
    end
    
    always @(posedge clk) begin
        if (~resetn) begin
            j_cnt <= 32'b0;
            b_cnt <= 32'b0;
            r_cnt <= 32'b0;
        end else if (stallreq_from_ex | stallreq_from_dcache) begin
            j_cnt <= j_cnt;
            b_cnt <= b_cnt;
            r_cnt <= r_cnt;
        end else if (~predict_flag) begin
            case (wrong_type)
                `TYPE_CALL: j_cnt <= j_cnt + 32'd1;
                `TYPE_PCR:  b_cnt <= b_cnt + 32'd1;
                `TYPE_RET:  r_cnt <= r_cnt + 32'd1;
                default:    ;
            endcase
        end
    end
    
endmodule
