`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/16 16:21:31
// Design Name: 
// Module Name: div
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


module div(

	input wire clk,
	input wire rst,
	
	input wire signed_div_i,  // 是否为有符号除法
	input wire [`RegBus] opdata1_i,  // 被除数
	input wire [`RegBus] opdata2_i,  // 除数
	input wire start_i,  // 是否开始除法运算
	input wire annul_i,  // 是否取消除法运算
	
	output reg [`DoubleRegBus] result_o,
	output reg ready_o
);

	wire [32:0] div_temp;
	reg [5:0] cnt;
	reg [64:0] dividend;
	reg [1:0] state;
	reg [31:0] divisor;
	
    // dividend的低32为保存的是被除数、中间结果，第k次迭代结束的时候dividend[k:0]
    // 保存的就是当前得到的中间结果，dividend[31:k+1]保存的就是被除数中还没有参与运算
    // 的数据,dividend高32位就是每次迭代时的被减数，所以dividend[63:32]就是minuend,
    // divisor就是除数n，此处进行的就是minuend-n运算，结果保存在div_temp中
	assign div_temp = {1'b0,dividend[63:32]} - {1'b0,divisor};

	always @ (posedge clk) begin
		if (rst == `RstEnable) begin
			state <= `DivFree;
			ready_o <= `DivResultNotReady;
			result_o <= {`ZeroWord,`ZeroWord};
		end else begin
		    case (state)
                `DivFree:      begin  // 除法模块空闲
                    if (start_i == `DivStart && annul_i == 1'b0) begin
                        if (opdata2_i == `ZeroWord)
                            state <= `DivByZero;
                        else begin
                            state <= `DivOn;
                            cnt <= 6'b000000;
                            dividend[63:33] <= 31'b0;
                            dividend[0] <= 1'b0;
                            if (signed_div_i == 1'b1 && opdata1_i[31] == 1'b1 )
                                dividend[32:1] <= ~opdata1_i + 1;
                            else
                                dividend[32:1] <= opdata1_i;
                            if (signed_div_i == 1'b1 && opdata2_i[31] == 1'b1 )
                                divisor <= ~opdata2_i + 1;
                            else
                                divisor <= opdata2_i;
                        end
                    end else begin
                        ready_o <= `DivResultNotReady;
                        result_o <= {`ZeroWord,`ZeroWord};
                    end          	
                end
                `DivByZero:		begin
                    dividend <= {`ZeroWord,`ZeroWord};
                    state <= `DivEnd;		 		
                end
                `DivOn:         begin
                    if(annul_i == 1'b0) begin
                        if(cnt != 6'b100000) begin  // cnt不为32，表示试商法还没有结束
                            if(div_temp[32] == 1'b1)
                                // 如果div_temp[32]为1，表示(minuend-n)结果小于0，
                                // 将dividend向左移一位，这样就将被除数还没有参与运算的
                                // 最高位加入到下一次迭代的被减数中，同时将0追加到中间结果
                                dividend <= {dividend[63:0] , 1'b0};
                            else
                                // 如果div_temp[32]为0，表示(minuend-n)结果大于等于0，
                                // 将减法的结果与被除数还没有参与运算的最高位加入到
                                // 下一次迭代的被减数中，同时将1追加到中间结果
                                dividend <= {div_temp[31:0] , dividend[31:0] , 1'b1};
                            cnt <= cnt + 1;
                        end else begin
                            if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1))
                                dividend[31:0] <= (~dividend[31:0] + 1);
                            if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ dividend[64]) == 1'b1))           
                                dividend[64:33] <= (~dividend[64:33] + 1);
                            state <= `DivEnd;
                            cnt <= 6'b000000;            	
                        end
                    end else
                        state <= `DivFree;  // 取消的话，直接回到DivFree状态
                end
                `DivEnd:       begin
                    result_o <= {dividend[64:33], dividend[31:0]};  
                    ready_o <= `DivResultReady;
                    if(start_i == `DivStop) begin
                        state <= `DivFree;
                        ready_o <= `DivResultNotReady;
                        result_o <= {`ZeroWord,`ZeroWord};       	
                    end		  	
                end
            endcase
        end
    end

endmodule
