`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/09 20:51:23
// Design Name: 
// Module Name: ex_sub2
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


// 需要单发射时，ex_sub2不会参与，因此只用执行算术逻辑等简单指令
module ex_sub2(

	input wire rst,
	
	// 送到执行阶段的信息
	input wire [`AluOpBus] aluop_i,
	input wire [`AluSelBus] alusel_i,
	input wire [`RegBus] reg1_i,
	input wire [`RegBus] reg2_i,
	input wire [`RegAddrBus] wd_i,
	input wire wreg_i,
	input wire [31:0] excepttype_i,
	
	input [`RegBus] hi_i,
	input [`RegBus] lo_i,

	// 执行的结果
	output reg [`RegAddrBus] wd_o,
	output reg wreg_o,
	output reg [`RegBus] wdata_o,
	
	// 处于执行阶段的指令对HI、LO寄存器的写操作请求
	output reg [`RegBus] hi_o,
	output reg [`RegBus] lo_o,
	output reg whilo_o,	
	
	output wire [31:0] excepttype_o
);

	reg [`RegBus] logicout;  // 保存逻辑运算结果
	reg [`RegBus] shiftres;  // 保存移位运算结果
	reg [`RegBus] moveres;  // 保存移动操作结果
	reg [`RegBus] arithmeticres;  // 保存算术运算结果
	
	// 算术运算有关的变量
	wire ov_sum;  // 保存溢出情况
	wire [`RegBus] reg2_i_mux;  // 保存输入的第二个操作数reg2_i的补码
	wire [`RegBus] result_sum;  // 保存加法结果
	
//	// 乘法操作有关的变量
//    wire [`RegBus] opdata1_mult;  // 乘法操作中的被乘数
//    wire [`RegBus] opdata2_mult;  // 乘法操作中的乘数
//    wire [`DoubleRegBus] hilo_temp;  // 临时保存乘法结果，宽度为64位
//    reg [`DoubleRegBus] mulres;  // 保存乘法结果，宽度为64位
    
    reg ovassert;
    	
    assign excepttype_o = {excepttype_i[31:13], ovassert, excepttype_i[11:0]};
    
// 计算变量的值
	// 如果是减法、有符号比较运算，那么reg2_i_mux等于
    // 第二个操作数reg2_i的补码，否则reg2_i_mux就等于第二个操作数reg2_i
	assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP) || 
                        (aluop_i == `EXE_SUBU_OP) ||
                        (aluop_i == `EXE_SLT_OP)) ?
                        (~reg2_i)+1 : reg2_i;
    
    assign result_sum = reg1_i + reg2_i_mux;                                         
    
    assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) ||
                    ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));

// 第一段：依据aluop_i指示的运算子类型进行计算	
    // 进行逻辑运算
    always @ (*) begin
        if(rst == `RstEnable)
            logicout = `ZeroWord;
        else begin
			case (aluop_i)
                `EXE_OR_OP:     logicout = reg1_i | reg2_i;
                `EXE_AND_OP:    logicout = reg1_i & reg2_i;
                `EXE_NOR_OP:    logicout = ~(reg1_i |reg2_i);
                `EXE_XOR_OP:    logicout = reg1_i ^ reg2_i;
				default:        logicout = `ZeroWord;
			endcase
		end  //if
	end  //always
    
    // 进行移位运算
    always @ (*) begin
        if(rst == `RstEnable)
            shiftres = `ZeroWord;
        else begin
            case (aluop_i)
                `EXE_SLL_OP:    shiftres = reg2_i << reg1_i[4:0] ;
                `EXE_SRL_OP:    shiftres = reg2_i >> reg1_i[4:0];
                `EXE_SRA_OP:    shiftres = ({32{reg2_i[31]}} << (6'd32-{1'b0, reg1_i[4:0]})) 
                                            | reg2_i >> reg1_i[4:0];
                default:        shiftres = `ZeroWord;
            endcase
        end  //if
    end  //always
    
    // 进行移动运算
    always @ (*) begin
        if (rst == `RstEnable) 
            moveres = `ZeroWord;
        else begin
            case (aluop_i)
                `EXE_MFHI_OP:   moveres = hi_i;
                `EXE_MFLO_OP:   moveres = lo_i;
                `EXE_MOVZ_OP:   moveres = reg1_i;
                `EXE_MOVN_OP:   moveres = reg1_i;
                default:        moveres = `ZeroWord;
            endcase
        end
    end
    
    // 进行算术运算
    always @ (*) begin
        if(rst == `RstEnable)
            arithmeticres = `ZeroWord;
        else begin
            case (aluop_i)
                `EXE_ADD_OP,`EXE_ADDU_OP,`EXE_ADDI_OP,`EXE_ADDIU_OP,`EXE_SUB_OP, `EXE_SUBU_OP:
                    arithmeticres = result_sum; 
                `EXE_SLT_OP:
                    arithmeticres = (reg1_i[31] & ~reg2_i[31]) ?
                                    1'b1 : (~reg1_i[31] & reg2_i[31]) ?
                                    1'b0 : result_sum[31];
                `EXE_SLTU_OP:   
                    arithmeticres = reg1_i < reg2_i;
                `EXE_CLZ_OP:        begin
                    arithmeticres = reg1_i[31] ? 0 : reg1_i[30] ? 1 : reg1_i[29] ? 2 :
                                     reg1_i[28] ? 3 : reg1_i[27] ? 4 : reg1_i[26] ? 5 :
                                     reg1_i[25] ? 6 : reg1_i[24] ? 7 : reg1_i[23] ? 8 : 
                                     reg1_i[22] ? 9 : reg1_i[21] ? 10 : reg1_i[20] ? 11 :
                                     reg1_i[19] ? 12 : reg1_i[18] ? 13 : reg1_i[17] ? 14 : 
                                     reg1_i[16] ? 15 : reg1_i[15] ? 16 : reg1_i[14] ? 17 : 
                                     reg1_i[13] ? 18 : reg1_i[12] ? 19 : reg1_i[11] ? 20 :
                                     reg1_i[10] ? 21 : reg1_i[9] ? 22 : reg1_i[8] ? 23 : 
                                     reg1_i[7] ? 24 : reg1_i[6] ? 25 : reg1_i[5] ? 26 : 
                                     reg1_i[4] ? 27 : reg1_i[3] ? 28 : reg1_i[2] ? 29 : 
                                     reg1_i[1] ? 30 : reg1_i[0] ? 31 : 32 ;
                end
                `EXE_CLO_OP:        begin
                    arithmeticres = ~reg1_i[31] ? 0 : ~reg1_i[30] ? 1 : ~reg1_i[29] ? 2 :
                                    ~reg1_i[28] ? 3 : ~reg1_i[27] ? 4 : ~reg1_i[26] ? 5 :
                                    ~reg1_i[25] ? 6 : ~reg1_i[24] ? 7 : ~reg1_i[23] ? 8 : 
                                    ~reg1_i[22] ? 9 : ~reg1_i[21] ? 10 : ~reg1_i[20] ? 11 :
                                    ~reg1_i[19] ? 12 : ~reg1_i[18] ? 13 : ~reg1_i[17] ? 14 : 
                                    ~reg1_i[16] ? 15 : ~reg1_i[15] ? 16 : ~reg1_i[14] ? 17 : 
                                    ~reg1_i[13] ? 18 : ~reg1_i[12] ? 19 : ~reg1_i[11] ? 20 :
                                    ~reg1_i[10] ? 21 : ~reg1_i[9] ? 22 : ~reg1_i[8] ? 23 : 
                                    ~reg1_i[7] ? 24 : ~reg1_i[6] ? 25 : ~reg1_i[5] ? 26 : 
                                    ~reg1_i[4] ? 27 : ~reg1_i[3] ? 28 : ~reg1_i[2] ? 29 : 
                                    ~reg1_i[1] ? 30 : ~reg1_i[0] ? 31 : 32 ;
                end
                default:
                    arithmeticres = `ZeroWord;
            endcase
        end
    end
    
//    // 进行乘法运算
//    //取得乘法操作的操作数，如果是有符号除法且操作数是负数，那么取反加一
//    assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP))
//                            && (reg1_i[31] == 1'b1)) ? (~reg1_i + 1) : reg1_i;   
//    assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP))
//                            && (reg2_i[31] == 1'b1)) ? (~reg2_i + 1) : reg2_i;
//    //得到临时乘法结果，保存在变量hilo_temp中
//    assign hilo_temp = opdata1_mult * opdata2_mult;
//    //对临时乘法结果进行修正，最终的乘法结果保存在变量mulres中
//	always @ (*) begin
//        if(rst == `RstEnable)
//            mulres = {`ZeroWord,`ZeroWord};
//        else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MUL_OP))
//            mulres = (reg1_i[31] ^ reg2_i[31]) ? ~hilo_temp + 1 : hilo_temp;
//        else
//            mulres = hilo_temp;
//    end
    
// 第二段：依据alusel_i指示的运算类型，选择一个运算结果作为最终结果
    always @ (*) begin
        wd_o = wd_i;	 	 	
        wreg_o = wreg_i;
        ovassert = 1'b0;
        case (alusel_i) 
            `EXE_RES_LOGIC:     wdata_o = logicout;
            `EXE_RES_SHIFT:     wdata_o = shiftres;
//            `EXE_RES_MUL:		wdata_o = mulres[31:0];
            `EXE_RES_ARITHMETIC: begin
                wdata_o = arithmeticres;
                if (((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) 
                    || (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1)) begin
                    wreg_o = `WriteDisable;
                    ovassert = 1'b1;
                end else begin
                    wreg_o = wreg_i;
                    ovassert = 1'b0;
                end
            end
            `EXE_RES_MOVE:      begin
                wdata_o = moveres;
                // MOVZ和MOVN两个条件移动指令需要做进一步条件判断
                case (aluop_i)
                    `EXE_MOVZ_OP:   wreg_o = (reg2_i != 0) ? `WriteDisable : `WriteEnable;
                    `EXE_MOVN_OP:   wreg_o = (reg2_i == 0) ? `WriteDisable : `WriteEnable;
                    default:        ;
                endcase  // case aluop_i
            end
            default:            wdata_o = `ZeroWord;
        endcase  // case alusel_i
    end	

// 第三段：如果是MTHI、MTLO、MULT、MULTU指令，那么需要给出whilo_o、hi_o、lo_o的值
    always @ (*) begin
		if(rst == `RstEnable) begin
			whilo_o = `WriteDisable;
			hi_o = `ZeroWord;
			lo_o = `ZeroWord;
//        end else if((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP)) begin
//            whilo_o = `WriteEnable;
//            hi_o = mulres[63:32];
//            lo_o = mulres[31:0];
		end else if(aluop_i == `EXE_MTHI_OP) begin
			whilo_o = `WriteEnable;
			hi_o = reg1_i;
			lo_o = lo_i;
		end else if(aluop_i == `EXE_MTLO_OP) begin
			whilo_o = `WriteEnable;
			hi_o = hi_i;
			lo_o = reg1_i;
		end else begin
			whilo_o = `WriteDisable;
			hi_o = `ZeroWord;
			lo_o = `ZeroWord;
		end				
	end
	
endmodule
