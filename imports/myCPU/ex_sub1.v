`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/09 20:53:16
// Design Name: 
// Module Name: ex_sub1
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

// ex_sub1中能够执行所有的指令
module ex_sub1(

	input wire rst,
	
	// 送到执行阶段的信息
	input wire [`AluOpBus] aluop_i,
	input wire [`AluSelBus] alusel_i,
	input wire [`RegBus] reg1_i,
	input wire [`RegBus] reg2_i,
	input wire [`RegAddrBus] wd_i,
	input wire wreg_i,
	input wire [`RegBus] imm_i,
	input wire [`InstAddrBus] inst_addr_i,
    input wire [`BPBPacketWidth] predict_pkt_i,
    input wire [31:0] excepttype_i,
    input wire mem_exception_flag,

    input wire [`RegBus] hi_i,
	input wire [`RegBus] lo_i,
	input wire LLbit_i,
	
	// 与除法模块有关的变量
    input wire [`DoubleRegBus] div_result_i,
    input wire div_ready_i,
    output reg [`RegBus] div_opdata1_o,
    output reg [`RegBus] div_opdata2_o,
    output reg div_start_o,
    output reg signed_div_o,
	
	// 执行的结果
	output reg [`RegAddrBus] wd_o,
	output reg wreg_o,
	output reg [`RegBus] wdata_o,
	
	// 转移指令有关的变量
	output reg ex_branch_flag,
	output reg [`RegBus] branch_target_addr,
	output reg predict_flag,  // 预测正确与否
	output reg [`BPBPacketWidth] corr_pkt,
	output wire predict_success,
	
	// 访存指令有关的变量
	output wire [`RegBus] mem_addr_o,
    output reg [`RegBus] dcache_addr_o,
    output wire mem_we_o,
    output reg [3:0] mem_sel_o,
    output reg [`RegBus] mem_data_o,
    output reg [2:0] mem_arsize_o,
    output wire mem_re_o,
    
    // CACHE指令有关的变量
    output reg [2:0] icache_op,
    output reg icache_creq,
    output reg [`RegBus] icache_caddr_o,
    output reg [`RegBus] icache_cdata_o,
    output reg [2:0] dcache_op,
    
    // 特权指令有关的变量
    input wire [2:0] cp0_sel_i,
    input wire [`RegAddrBus] cp0_addr_i,
    input wire [`RegBus] cp0_data_i,
    input wire [2:0] mem_cp0_wsel_i,
    input wire mem_cp0_we_i,
    input wire [`RegAddrBus] mem_cp0_waddr_i,
    input wire [2:0] commit_cp0_wsel_i,
    input wire commit_cp0_we_i,
    input wire [`RegAddrBus] commit_cp0_waddr_i,
    output reg cp0_we_o,
    output reg [`RegAddrBus] cp0_waddr_o,
    output reg [`RegBus] cp0_wdata_o,
    output wire [`RegAddrBus] cp0_raddr_o,
    
    // 乘累加、乘累减指令所需要的变量
    input wire [`DoubleRegBus] hilo_temp_i,
    input wire [1:0] cnt_i,
    output reg [`DoubleRegBus] hilo_temp_o,
    output reg [1:0] cnt_o,
	
    // 处于执行阶段的指令对HI、LO寄存器的写操作请求
    output reg [`RegBus] hi_o,
    output reg [`RegBus] lo_o,
    output reg whilo_o,
    
    // LLbit
    output reg LLbit_o,
    output reg LLbit_we_o,
    
    output wire stallreq_from_ex, 
    output wire [31:0] excepttype_o   	
);

    wire [`InstAddrBus] inst_addr_plus_4;
    wire [`InstAddrBus] inst_addr_plus_8;
    
	reg [`RegBus] logicout;  // 保存逻辑运算结果
	reg [`RegBus] shiftres;  // 保存移位运算结果
	reg [`RegBus] moveres;  // 保存移动操作结果
	reg [`RegBus] arithmeticres;  // 保存算术运算结果
	reg [`RegBus] link_addr;  // 保存链接指令的返回地址;
	reg [`RegBus] scres;  // 保存SC指令操作结果
        
    // 算术运算有关的变量
    wire ov_sum;  // 保存溢出情况
    wire [`RegBus] reg2_i_mux;  // 保存输入的第二个操作数reg2_i的补码
    wire [`RegBus] result_sum;  // 保存加法结果
    
    // 乘法操作有关的变量
    reg [`DoubleRegBus] hilo_temp1;
    wire [`DoubleRegBus] mulres;  // 保存有符号数乘法结果，宽度为64位
    wire [`DoubleRegBus] umulres; // 保存无符号数乘法结果，宽度为64位  
    
    // 访存操作有关的变量
    reg mem_re;
    reg mem_we;    
    
    reg stallreq_for_div;  // 是否由于除法运算导致流水线暂停
    reg stallreq_for_cp0;  // 是否由于cp0相关导致流水线暂停
    reg stallreq_for_madd_msub;  // 是否由于madd、msub指令导致流水线暂停
    
    // 异常判断
    reg trapassert;
    reg ovassert;
    reg adelassert;
    reg adesassert;
    
    assign stallreq_from_ex = stallreq_for_div | stallreq_for_cp0 | stallreq_for_madd_msub;
    assign excepttype_o = {excepttype_i[31:14], trapassert, ovassert, 
                            excepttype_i[11:6], adesassert, adelassert | 
                            excepttype_i[4], excepttype_i[3:0]};
    assign inst_addr_plus_4 = inst_addr_i + 32'h4;
    assign inst_addr_plus_8 = inst_addr_i + 32'h8;
    assign mem_addr_o = reg1_i + imm_i;
    assign mem_re_o = mem_re & ~|excepttype_o & ~mem_exception_flag;
    assign mem_we_o = mem_we & ~|excepttype_o & ~mem_exception_flag;
    assign cp0_raddr_o = cp0_addr_i;
    assign predict_success = (predict_pkt_i[34] == ex_branch_flag) & (corr_pkt[1:0] == `TYPE_PCR);
    
    // cp0相关导致流水线暂停
    always @ (*) begin
        if (rst == `RstEnable)
            stallreq_for_cp0 = `NoStop;
        else if (mem_cp0_we_i == `WriteEnable && mem_cp0_waddr_i == cp0_addr_i && mem_cp0_wsel_i == cp0_sel_i) 
            stallreq_for_cp0 = `Stop;
        else if (commit_cp0_we_i == `WriteEnable && commit_cp0_waddr_i == cp0_addr_i && commit_cp0_wsel_i == cp0_sel_i) 
            stallreq_for_cp0 = `Stop;
        else 
            stallreq_for_cp0 = `NoStop;
    end
    
// 计算变量的值
    // 如果是减法、有符号比较运算，那么reg2_i_mux等于
    // 第二个操作数reg2_i的补码，否则reg2_i_mux就等于第二个操作数reg2_i
    assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP) || 
                        (aluop_i == `EXE_SUBU_OP) ||
                        (aluop_i == `EXE_SLT_OP) || 
                        (aluop_i == `EXE_TLT_OP) ||
                        (aluop_i == `EXE_TLTI_OP) || 
                        (aluop_i == `EXE_TGE_OP) ||
                        (aluop_i == `EXE_TGEI_OP)) ?
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
                `EXE_SLL_OP:    shiftres = reg2_i << reg1_i[4:0];
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
                `EXE_MFC0_OP:   moveres = cp0_data_i;
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
    
    // 判断是否发生自陷异常
    always @ (*) begin
        if (rst == `RstEnable) 
            trapassert = `TrapNotAssert;
        else begin
            trapassert = `TrapNotAssert;
            case (aluop_i)
                `EXE_TEQ_OP, `EXE_TEQI_OP: trapassert = reg1_i == reg2_i ? `TrapAssert : `TrapNotAssert;
                `EXE_TGE_OP, `EXE_TGEI_OP: begin
                    if (~reg1_i[31] & reg2_i[31]) trapassert = `TrapAssert;
                    else if (reg1_i[31] & ~reg2_i[31]) trapassert = `TrapNotAssert;
                    else trapassert = ~result_sum[31] ? `TrapAssert : `TrapNotAssert;
                end
                `EXE_TGEU_OP, `EXE_TGEIU_OP: trapassert = reg1_i >= reg2_i ? `TrapAssert : `TrapNotAssert;
                `EXE_TLT_OP, `EXE_TLTI_OP: begin
                    if (~reg1_i[31] & reg2_i[31]) trapassert = `TrapNotAssert;
                    else if (reg1_i[31] & ~reg2_i[31]) trapassert = `TrapAssert;
                    else trapassert = result_sum[31] ? `TrapAssert : `TrapNotAssert;
                end
                `EXE_TLTU_OP, `EXE_TLTIU_OP: trapassert = reg1_i < reg2_i ? `TrapAssert : `TrapNotAssert;
                `EXE_TNE_OP, `EXE_TNEI_OP: trapassert = reg1_i != reg2_i ? `TrapAssert : `TrapNotAssert;
                default: ;
            endcase
        end
    end
    
    // 进行乘法运算
    // 有符号数乘法运算
    mult_gen_0 mult (
        .A(reg1_i),      // input wire [31 : 0] A
        .B(reg2_i),      // input wire [31 : 0] B
        .P(mulres)      // output wire [63 : 0] P
    );
    
    multu_gen_1 multu (
        .A(reg1_i),  // input wire [31 : 0] A
        .B(reg2_i),  // input wire [31 : 0] B
        .P(umulres)  // output wire [63 : 0] P
    );
    
    // 乘累加、乘累减
    always @ (*) begin
        if(rst == `RstEnable) begin
            hilo_temp_o = {`ZeroWord,`ZeroWord};
            cnt_o = 2'b00;
            stallreq_for_madd_msub = `NoStop;
            hilo_temp1 = {`ZeroWord,`ZeroWord};
        end else begin
            hilo_temp_o = {`ZeroWord,`ZeroWord};
            cnt_o = 2'b00;
            stallreq_for_madd_msub = `NoStop;  
            hilo_temp1 = {`ZeroWord, `ZeroWord};
            case (aluop_i) 
                `EXE_MADD_OP, `EXE_MADDU_OP:    begin
                    if(cnt_i == 2'b00) begin
                        hilo_temp_o = mulres;
                        cnt_o = 2'b01;
                        stallreq_for_madd_msub = `Stop;
                        hilo_temp1 = {`ZeroWord,`ZeroWord};
                    end else if(cnt_i == 2'b01) begin
                        hilo_temp_o = {`ZeroWord,`ZeroWord};                        
                        cnt_o = 2'b10;
                        hilo_temp1 = hilo_temp_i + {hi_i,lo_i};
                        stallreq_for_madd_msub = `NoStop;
                    end
                end
                `EXE_MSUB_OP, `EXE_MSUBU_OP:    begin
                    if(cnt_i == 2'b00) begin
                        hilo_temp_o =  ~mulres + 1 ;
                        cnt_o = 2'b01;
                        stallreq_for_madd_msub = `Stop;
                    end else if(cnt_i == 2'b01)begin
                        hilo_temp_o = {`ZeroWord,`ZeroWord};                        
                        cnt_o = 2'b10;
                        hilo_temp1 = hilo_temp_i + {hi_i,lo_i};
                        stallreq_for_madd_msub = `NoStop;
                    end                
                end
                default:    begin
//                    hilo_temp_o = {`ZeroWord,`ZeroWord};
//                    cnt_o = 2'b00;
//                    stallreq_for_madd_msub = `NoStop;                
                end
            endcase
        end
    end
    
    // 进行除法运算
    always @ (*) begin
        if(rst == `RstEnable) begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end else begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;    
            case (aluop_i) 
                `EXE_DIV_OP:        begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = reg1_i;
                        div_opdata2_o = reg2_i;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = reg1_i;
                        div_opdata2_o = reg2_i;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end else begin                        
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end                    
                end
                `EXE_DIVU_OP:       begin
                    if(div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = reg1_i;
                        div_opdata2_o = reg2_i;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end else if(div_ready_i == `DivResultReady) begin
                        div_opdata1_o = reg1_i;
                        div_opdata2_o = reg2_i;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end else begin                        
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end                    
                end
                default:    ;
            endcase
        end
    end
    
    // 进行转移运算
    always @ (*) begin
        if (rst == `RstEnable) begin
            ex_branch_flag = `NotBranch;
            branch_target_addr = `ZeroWord;
            predict_flag = `True_v;
            corr_pkt = {`NotBranch, `ZeroWord, `TYPE_NUL};
        end else begin
            case (aluop_i)
                `EXE_J_OP:      begin
                    ex_branch_flag = `Branch;
                    branch_target_addr = {inst_addr_plus_4[31:28], imm_i[27:0]};
                    predict_flag = (predict_pkt_i[34] == `Branch && 
                                    predict_pkt_i[33:2] == branch_target_addr) ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_CALL};                                   
                end
                `EXE_JAL_OP:    begin
                    ex_branch_flag = `Branch;
                    branch_target_addr = {inst_addr_plus_4[31:28], imm_i[27:0]};
                    predict_flag = (predict_pkt_i[34] == `Branch && 
                                    predict_pkt_i[33:2] == branch_target_addr) ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_CALL};
                end
                `EXE_JR_OP:     begin
                    ex_branch_flag = `Branch;
                    branch_target_addr = reg1_i;
                    predict_flag = (predict_pkt_i[34] == `Branch && 
                                    predict_pkt_i[33:2] == branch_target_addr) ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_RET};
                end
                `EXE_JALR_OP:   begin
                    ex_branch_flag = `Branch;
                    branch_target_addr = reg1_i;
                    predict_flag = (predict_pkt_i[34] == `Branch && 
                                    predict_pkt_i[33:2] == branch_target_addr) ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_PCR};
                end
                `EXE_BEQ_OP:    begin
                    ex_branch_flag = (reg1_i == reg2_i) ? `Branch : `NotBranch;
                    branch_target_addr = inst_addr_plus_4 + imm_i;
                    predict_flag = ((predict_pkt_i[34] == `Branch && 
                                    ex_branch_flag == `Branch &&
                                    predict_pkt_i[33:2] == branch_target_addr) ||
                                    (predict_pkt_i[34] == `NotBranch &&
                                    ex_branch_flag == `NotBranch))  ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_PCR};
                end
                `EXE_BGTZ_OP:   begin
                     ex_branch_flag = (reg1_i[31] == 1'b0 && reg1_i != 32'b0) ? `Branch : `NotBranch;
                     branch_target_addr = inst_addr_plus_4 + imm_i;
                     predict_flag = ((predict_pkt_i[34] == `Branch && 
                                     ex_branch_flag == `Branch &&
                                     predict_pkt_i[33:2] == branch_target_addr) ||
                                     (predict_pkt_i[34] == `NotBranch &&
                                     ex_branch_flag == `NotBranch))  ?
                                     `True_v : `False_v;
                     corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_PCR};
                end
                `EXE_BLEZ_OP:   begin
                    ex_branch_flag = (reg1_i[31] == 1'b1 || reg1_i == 32'b0) ? `Branch : `NotBranch;
                    branch_target_addr = inst_addr_plus_4 + imm_i;
                    predict_flag = ((predict_pkt_i[34] == `Branch && 
                                    ex_branch_flag == `Branch &&
                                    predict_pkt_i[33:2] == branch_target_addr) ||
                                    (predict_pkt_i[34] == `NotBranch &&
                                    ex_branch_flag == `NotBranch))  ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_PCR};
                end
                `EXE_BNE_OP:    begin
                    ex_branch_flag = (reg1_i != reg2_i) ? `Branch : `NotBranch;
                    branch_target_addr = inst_addr_plus_4 + imm_i;
                    predict_flag = ((predict_pkt_i[34] == `Branch && 
                                    ex_branch_flag == `Branch &&
                                    predict_pkt_i[33:2] == branch_target_addr) ||
                                    (predict_pkt_i[34] == `NotBranch &&
                                    ex_branch_flag == `NotBranch))  ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_PCR};
                end
                `EXE_BGEZ_OP:   begin
                    ex_branch_flag = (reg1_i[31] == 1'b0) ? `Branch : `NotBranch;
                    branch_target_addr = inst_addr_plus_4 + imm_i;
                    predict_flag = ((predict_pkt_i[34] == `Branch && 
                                    ex_branch_flag == `Branch &&
                                    predict_pkt_i[33:2] == branch_target_addr) ||
                                    (predict_pkt_i[34] == `NotBranch &&
                                    ex_branch_flag == `NotBranch))  ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_PCR};
                end
                `EXE_BGEZAL_OP: begin
                    ex_branch_flag = (reg1_i[31] == 1'b0) ? `Branch : `NotBranch;
                    branch_target_addr = inst_addr_plus_4 + imm_i;
                    predict_flag = ((predict_pkt_i[34] == `Branch && 
                                    ex_branch_flag == `Branch &&
                                    predict_pkt_i[33:2] == branch_target_addr) ||
                                    (predict_pkt_i[34] == `NotBranch &&
                                    ex_branch_flag == `NotBranch))  ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_PCR};
                end
                `EXE_BLTZ_OP:   begin
                    ex_branch_flag = (reg1_i[31] == 1'b1) ? `Branch : `NotBranch;
                    branch_target_addr = inst_addr_plus_4 + imm_i;
                    predict_flag = ((predict_pkt_i[34] == `Branch && 
                                    ex_branch_flag == `Branch &&
                                    predict_pkt_i[33:2] == branch_target_addr) ||
                                    (predict_pkt_i[34] == `NotBranch &&
                                    ex_branch_flag == `NotBranch))  ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_PCR};
                end
                `EXE_BLTZAL_OP: begin
                    ex_branch_flag = (reg1_i[31] == 1'b1) ? `Branch : `NotBranch;
                    branch_target_addr = inst_addr_plus_4 + imm_i;
                    predict_flag = ((predict_pkt_i[34] == `Branch && 
                                    ex_branch_flag == `Branch &&
                                    predict_pkt_i[33:2] == branch_target_addr) ||
                                    (predict_pkt_i[34] == `NotBranch &&
                                    ex_branch_flag == `NotBranch))  ?
                                    `True_v : `False_v;
                    corr_pkt = {ex_branch_flag, branch_target_addr, `TYPE_PCR};
                end
                default:        begin
                    ex_branch_flag = `NotBranch;
                    branch_target_addr = `ZeroWord;
                    predict_flag = `True_v;
                    corr_pkt = {`NotBranch, `ZeroWord, `TYPE_NUL};
                end
            endcase  // case aluop_i
        end
    end
    
    always @ (*) begin
        if (rst == `RstEnable) 
            link_addr = `ZeroWord;
        else if (aluop_i == `EXE_JAL_OP ||
                aluop_i == `EXE_JALR_OP ||
                aluop_i == `EXE_BGEZAL_OP ||
                aluop_i == `EXE_BLTZAL_OP)
            link_addr = inst_addr_plus_8;
        else
            link_addr = `ZeroWord;
    end
    
    // 进行CACHE指令运算
    always @ (*) begin
        if (rst == `RstEnable) begin
            icache_op = `RESERVED;
            icache_creq = `Invalid;
            icache_caddr_o = `ZeroWord;
            icache_cdata_o = `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_III_OP:    begin
                    icache_op = `INDEX_INVALID;
                    icache_creq = `Valid;
                    icache_caddr_o = mem_addr_o;
                    icache_cdata_o = `ZeroWord;
                end
                `EXE_IIST_OP:   begin
                    icache_op = `INDEX_STORE_TAG;
                    icache_creq = `Valid;
                    icache_caddr_o = mem_addr_o;
                    icache_cdata_o = cp0_data_i;
                end
                `EXE_IHI_OP:    begin
                    icache_op = `HIT_INVALID;
                    icache_creq = `Valid;
                    icache_caddr_o = mem_addr_o;
                    icache_cdata_o = `ZeroWord;
                end
                default:        begin
                    icache_op = `RESERVED;
                    icache_creq = `Invalid;
                    icache_caddr_o = `ZeroWord;
                    icache_cdata_o = `ZeroWord;
                end
            endcase
        end
    end
                
    // 进行访存运算和CACHE指令的dcache部分的运算
    always @ (*) begin
        if (rst == `RstEnable) begin
            dcache_op = `RESERVED;
            dcache_addr_o = `ZeroWord;
            mem_we = `WriteDisable;
            mem_sel_o = 4'b0000;
            mem_data_o = `ZeroWord;
            mem_re = `ReadDisable;
            mem_arsize_o = 3'b010;
            scres = `ZeroWord;
            LLbit_o = 1'b0;
            LLbit_we_o = `WriteDisable;
            adelassert = `False_v;
            adesassert = `False_v;
        end else begin
            dcache_op = `RESERVED;
            dcache_addr_o = `ZeroWord;
            mem_we = `WriteDisable;
            mem_sel_o = 4'b0000;
            mem_data_o = `ZeroWord;
            mem_re = `ReadDisable;
            mem_arsize_o = 3'b010;
            scres = `ZeroWord;
            LLbit_o = 1'b0;
            LLbit_we_o = `WriteDisable;
            adelassert = `False_v;
            adesassert = `False_v;
            case (aluop_i)
                `EXE_LB_OP: begin
                    dcache_addr_o = mem_addr_o;
                    mem_arsize_o = 3'b000;
                    mem_we = `WriteDisable;
                    mem_re = `ReadEnable;
                    case (mem_addr_o[1:0])
                        2'b00: mem_sel_o = 4'b0001;
                        2'b01: mem_sel_o = 4'b0010;
                        2'b10: mem_sel_o = 4'b0100;
                        2'b11: mem_sel_o = 4'b1000;
                        default: ;
                    endcase
                end
                `EXE_LBU_OP: begin
                    dcache_addr_o = mem_addr_o;
                    mem_arsize_o = 3'b000;
                    mem_we = `WriteDisable;
                    mem_re = `ReadEnable;
                    case (mem_addr_o[1:0])
                        2'b00: mem_sel_o = 4'b0001;
                        2'b01: mem_sel_o = 4'b0010;
                        2'b10: mem_sel_o = 4'b0100;
                        2'b11: mem_sel_o = 4'b1000;
                        default: ;
                    endcase
                end
                `EXE_LH_OP: begin
                    dcache_addr_o = mem_addr_o;
                    mem_arsize_o = 3'b001;
                    mem_we = `WriteDisable;
                    mem_re = `ReadEnable;
                    case (mem_addr_o[1:0])
                        2'b00: mem_sel_o = 4'b0011;
                        2'b10: mem_sel_o = 4'b1100;
                        default: begin
                            mem_sel_o = 4'b0000;
                            adelassert = `True_v;
                        end
                    endcase
                end
                `EXE_LHU_OP: begin
                    dcache_addr_o = mem_addr_o;
                    mem_arsize_o = 3'b001;
                    mem_we = `WriteDisable;
                    mem_re = `ReadEnable;
                    case (mem_addr_o[1:0])
                        2'b00: mem_sel_o = 4'b0011;
                        2'b10: mem_sel_o = 4'b1100;
                        default: begin
                            mem_sel_o = 4'b0000;
                            adelassert = `True_v;
                        end
                    endcase
                end
                `EXE_LW_OP: begin
                    dcache_addr_o = mem_addr_o;
                    mem_arsize_o = 3'b010;
                    mem_we = `WriteDisable;
                    mem_re = `ReadEnable;
                    mem_sel_o = 4'b1111;
                    adelassert = | mem_addr_o[1:0];
                end
                `EXE_LWL_OP: begin
                    dcache_addr_o = {mem_addr_o[31:2], 2'b00};
                    mem_arsize_o = 3'b010;
                    mem_we = `WriteDisable;
                    mem_re = `ReadEnable;
                    mem_sel_o = 4'b1111;
                end
                `EXE_LWR_OP: begin
                    dcache_addr_o = {mem_addr_o[31:2], 2'b00};
                    mem_arsize_o = 3'b010;
                    mem_we = `WriteDisable;
                    mem_re = `ReadEnable;
                    mem_sel_o = 4'b1111;
                end
                `EXE_SB_OP: begin
                    dcache_addr_o = mem_addr_o;
                    mem_we = `WriteEnable;
                    mem_data_o = {reg2_i[7:0], reg2_i[7:0], reg2_i[7:0], reg2_i[7:0]};
                    case (mem_addr_o[1:0])
                        2'b00: mem_sel_o = 4'b0001;
                        2'b01: mem_sel_o = 4'b0010;
                        2'b10: mem_sel_o = 4'b0100;
                        2'b11: mem_sel_o = 4'b1000;
                        default: ;
                    endcase
                end
                `EXE_SH_OP: begin
                    dcache_addr_o = mem_addr_o;
                    mem_we = `WriteEnable;
                    mem_data_o = {reg2_i[15:0], reg2_i[15:0]};
                    case (mem_addr_o[1:0])
                        2'b00: mem_sel_o = 4'b0011;
                        2'b10: mem_sel_o = 4'b1100;
                        default: begin
                            mem_sel_o = 4'b0000;
                            adesassert = `True_v;
                        end
                    endcase
                end
                `EXE_SW_OP: begin
                    dcache_addr_o = mem_addr_o;
                    mem_we = `WriteEnable;
                    mem_data_o = reg2_i;
                    mem_sel_o = 4'b1111;
                    adesassert = | mem_addr_o[1:0];
                end
                `EXE_SWL_OP: begin
                    dcache_addr_o = {mem_addr_o[31:2], 2'b00};
                    mem_we = `WriteEnable;
                    case (mem_addr_o[1:0])
                        2'b00:  begin						  
                            mem_sel_o = 4'b0001;
                            mem_data_o = {24'b0,reg2_i[31:24]};
                        end
                        2'b01:  begin
                            mem_sel_o = 4'b0011;
                            mem_data_o = {16'b0,reg2_i[31:16]};
                        end
                        2'b10:  begin
                            mem_sel_o = 4'b0111;
                            mem_data_o = {8'b0,reg2_i[31:8]};
                        end
                        2'b11:  begin
                            mem_sel_o = 4'b1111;    
                            mem_data_o = reg2_i;
                        end
                        default: ;
                    endcase                
                end
                `EXE_SWR_OP: begin
                    dcache_addr_o = {mem_addr_o[31:2], 2'b00};
                    mem_we = `WriteEnable;
                    case (mem_addr_o[1:0])
                        2'b00:	begin						  
                            mem_sel_o = 4'b1111;    
                            mem_data_o = reg2_i;
                        end
                        2'b01:  begin
                            mem_sel_o = 4'b1110;
                            mem_data_o = {reg2_i[23:0],8'b0};
                        end
                        2'b10:  begin
                            mem_sel_o = 4'b1100;
                            mem_data_o = {reg2_i[15:0],16'b0};
                        end
                        2'b11:  begin
                            mem_sel_o = 4'b1000;    
                            mem_data_o = {reg2_i[7:0],24'b0};
                        end
                        default: ;
                    endcase                
                end
                `EXE_LL_OP: begin
                    dcache_addr_o = mem_addr_o;
                    mem_we = `WriteDisable;
                    mem_re = `ReadEnable;
                    LLbit_o = 1'b1;
                    LLbit_we_o = `WriteEnable;
                end
                `EXE_SC_OP: begin
                    if (LLbit_i == 1'b1) begin
                        dcache_addr_o = mem_addr_o;
                        mem_we = `WriteEnable;
                        scres = 32'b1;
                        mem_sel_o = 4'b1111;
                        mem_data_o = reg2_i;
                        LLbit_o = 1'b0;
                        LLbit_we_o = `WriteEnable;
                    end else begin
                        scres = 32'b0;
                    end
                end
                `EXE_DIWI_OP:   begin
                    dcache_addr_o = mem_addr_o;
                    mem_we = `WriteEnable;
                    dcache_op = `INDEX_WRITEBACK_INVALID;
                end
                `EXE_DIST_OP:   begin
                    dcache_addr_o = mem_addr_o;
                    mem_we = `WriteEnable;
                    mem_data_o = cp0_data_i;
                    mem_sel_o = 4'b1111;
                    dcache_op = `INDEX_STORE_TAG;
                end
                `EXE_DHI_OP:    begin
                    dcache_addr_o = mem_addr_o;
                    mem_we = `WriteEnable;
                    dcache_op = `HIT_INVALID;
                end
                `EXE_DHWI_OP:   begin
                    dcache_addr_o = mem_addr_o;
                    mem_we = `WriteEnable;
                    dcache_op = `HIT_WRITEBACK_INVALID;
                end
                default: ;
            endcase
        end
    end
// 第二段：依据alusel_i指示的运算类型，选择一个运算结果作为最终结果
    always @ (*) begin
        wd_o = wd_i;              
        wreg_o = wreg_i;
        ovassert = 1'b0;
        case (alusel_i) 
            `EXE_RES_LOGIC:         wdata_o = logicout;
            `EXE_RES_SHIFT:         wdata_o = shiftres;
            `EXE_RES_MUL:           wdata_o = mulres[31:0];
            `EXE_RES_JUMP_BRANCH:   wdata_o = link_addr;
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
            `EXE_RES_LOAD_STORE:    wdata_o = scres;
            default:                wdata_o = `ZeroWord;
        endcase  // case alusel_i
    end    

// 第三段：如果是MTHI、MTLO、MULT、MULTU指令，那么需要给出whilo_o、hi_o、lo_o的值
    always @ (*) begin
        if(rst == `RstEnable) begin
            whilo_o = `WriteDisable;
            hi_o = `ZeroWord;
            lo_o = `ZeroWord;
        end else if (aluop_i == `EXE_MULT_OP) begin
            whilo_o = `WriteEnable;
            hi_o = mulres[63:32];
            lo_o = mulres[31:0];
        end else if (aluop_i == `EXE_MULTU_OP) begin
            whilo_o = `WriteEnable;
            hi_o = umulres[63:32];
            lo_o = umulres[31:0];
        end else if (((aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MADDU_OP) ||
                    (aluop_i == `EXE_MSUB_OP) || (aluop_i == `EXE_MSUBU_OP)) && (cnt_o == 2'b10))begin
            whilo_o = `WriteEnable;
            hi_o = hilo_temp1[63:32];
            lo_o = hilo_temp1[31:0];
        end else if(((aluop_i == `EXE_DIV_OP) || (aluop_i == `EXE_DIVU_OP)) && (div_ready_i == `DivResultReady)) begin
            whilo_o = `WriteEnable;
            hi_o = div_result_i[63:32];
            lo_o = div_result_i[31:0];
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
    
// 第四段：给出mtc0指令的执行结果
    always @ (*) begin
        if (rst == `RstEnable) begin
            cp0_we_o = `WriteDisable;
            cp0_waddr_o = `NOPRegAddr;
            cp0_wdata_o = `ZeroWord;
        end else if (aluop_i == `EXE_MTC0_OP) begin
            cp0_we_o = `WriteEnable;
            cp0_waddr_o = cp0_addr_i;
            cp0_wdata_o = reg1_i;
        end else begin
            cp0_we_o = `WriteDisable;
            cp0_waddr_o = `NOPRegAddr;
            cp0_wdata_o = `ZeroWord;
        end
    end
endmodule