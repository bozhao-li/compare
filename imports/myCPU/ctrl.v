`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/16 15:13:32
// Design Name: 
// Module Name: ctrl
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


module ctrl(

	input wire rst,
	input wire predict_flag,
	input wire exception_flag,
	input wire [4:0] excepttype_i,
	input wire [`RegBus] cp0_epc_i,
	input wire [`RegBus] cp0_ebase_i,
	input wire stallreq_from_id,  // 来自译码阶段的暂停请求
	input wire stallreq_from_ex,  // 来自执行阶段的暂停请求
	input wire stallreq_from_dcache,  // 来自dcache的暂停请求
//    input wire stallreq_from_delayslot,  // 来自延迟槽的暂停请求
	
	// stall从低位到高位分别表示译码、执行、访存、提交阶段是否暂停，为1表示暂停
	output reg [3:0] stall,
	
	output reg flush,
	output reg flush_cause,
	output reg [`RegBus] epc_o
	
);

	always @ (*) begin
		if(rst == `RstEnable) begin
			stall = 4'b0000;
			flush = 1'b0;
			flush_cause = `Exception;
			epc_o = `ZeroWord;
        end else if (exception_flag) begin
            stall = 4'b0000;
            flush = 1'b1;
            flush_cause = `Exception;
            case (excepttype_i)
                `EXCEPTION_INT,`EXCEPTION_ADEL, `EXCEPTION_ADES, `EXCEPTION_SYS,
                `EXCEPTION_BP, `EXCEPTION_RI, `EXCEPTION_OV, `EXCEPTION_TR: epc_o = cp0_ebase_i;
                `EXCEPTION_ERET: epc_o = cp0_epc_i;
                default: epc_o = `ZeroWord;
            endcase
        end else if (stallreq_from_dcache == `Stop) begin
            stall = 4'b0111;
            flush = 1'b0;
            flush_cause = `Exception;
            epc_o = `ZeroWord;
        end else if(predict_flag == `False_v) begin
            stall = 4'b0000;
            flush = 1'b1;
            flush_cause = `FailedBranchPrediction;
            epc_o = `ZeroWord;
        end else if(stallreq_from_ex == `Stop) begin
			stall = 4'b0011;
            flush = 1'b0;
            flush_cause = `Exception;
            epc_o = `ZeroWord;
		end else if(stallreq_from_id == `Stop) begin
			stall = 4'b0001;		
            flush = 1'b0;
            flush_cause = `Exception;	
            epc_o = `ZeroWord;
		end else begin
			stall = 4'b0000;
            flush = 1'b0;
            flush_cause = `Exception;
            epc_o = `ZeroWord;
		end  //if
	end  //always
	
//	// stall		
//    always @(*) begin
//		if(rst == `RstEnable)                       stall = 4'b0000;
//        else if (stallreq_from_dcache == `Stop)     stall = 4'b0111;
//        else if(stallreq_from_ex == `Stop)          stall = 4'b0011;
//		else if(stallreq_from_id == `Stop)          stall = 4'b0001;		
//		else                                        stall = 4'b0000;
//	end  //always    
	
//	// flush    
//	always @ (*) begin
//		if(rst == `RstEnable) begin
//			flush = 1'b0;
//			flush_cause = `Exception;
//			epc_o = `ZeroWord;
//        end else if (exception_flag) begin
//            flush = 1'b1;
//            flush_cause = `Exception;
//            case (excepttype_i)
//                `EXCEPTION_INT,`EXCEPTION_ADEL, `EXCEPTION_ADES, `EXCEPTION_SYS,
//                `EXCEPTION_BP, `EXCEPTION_RI, `EXCEPTION_OV, `EXCEPTION_TR: epc_o = cp0_ebase_i;
//                `EXCEPTION_ERET: epc_o = cp0_epc_i;
//                default: epc_o = `ZeroWord;
//            endcase
//        end else if(predict_flag == `False_v) begin
//            flush = 1'b1;
//            flush_cause = `FailedBranchPrediction;
//            epc_o = `ZeroWord;
//		end else begin
//            flush = 1'b0;
//            flush_cause = `Exception;
//            epc_o = `ZeroWord;
//		end  //if
//	end  //always

endmodule
