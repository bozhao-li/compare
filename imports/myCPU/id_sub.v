`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/09 19:03:34
// Design Name: 
// Module Name: id_sub
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

// 译码阶段的译码子部件
module id_sub(
    input wire clk,
    input wire rst,
	input wire [`InstAddrBus] inst_addr_i,  // 译码阶段的指令对应的地址
	input wire [`InstBus] inst_i,  // 译码阶段的指令

    // 读取的regfile的值
//	input wire [`RegBus] reg1_data_i,  // 从regfile输入的第一个读端口的输出
//	input wire [`RegBus] reg2_data_i,

	// 送到regfile的信息
	output reg reg1_read_o,  // regfile的第一个读端口的读使能信号
	output reg reg2_read_o,     
	output reg [`RegAddrBus] reg1_addr_o,  // regfile的第一个读端口的读地址信号
	output reg [`RegAddrBus] reg2_addr_o, 	      
	
	// 送到执行阶段的信息
	output reg [`AluOpBus] aluop_o,
	output reg [`AluSelBus] alusel_o,
//	output reg [`RegBus] reg1_o,  // 源操作数1
//	output reg [`RegBus] reg2_o,
	output reg [`RegAddrBus] wd_o,  // 要写入的目的寄存器的地址
	output reg wreg_o,  // 是否有要写入的目的寄存器
	output reg [`RegBus] imm,  // 保存指令执行所需要的立即数
	output reg [`RegAddrBus] cp0_addr_o,
	output reg [2:0] cp0_sel_o,
	output wire [31:0] excepttype_o,

	// 对hi、lo寄存器的读写信息
	output reg hi_re,
	output reg hi_we,
	output reg lo_re,
	output reg lo_we,
	
	// 指令信息
	output reg is_md,  // 是否是乘除法指令
	output reg is_jb,  // 是否是转移指令
	output reg is_ls,  // 是否是访存指令
	output reg is_cp0,  // 是否是特权指令
	output reg is_bly,  // 是否是branch_likely指令
	input wire pre_inst_is_load,  // 上一次指令是否是加载指令
	
	// 解决数据相关问题
    // 处于执行阶段的指令要写入的目的寄存器信息
//    input wire ex_we_i1,
//    input wire [`RegBus] ex_wdata_i1,
    input wire [`RegAddrBus] ex_waddr_i1,
//    input wire ex_we_i2,
//    input wire [`RegBus] ex_wdata_i2,
    input wire [`RegAddrBus] ex_waddr_i2,
        
    //处于访存阶段的指令要写入的目的寄存器信息
//    input wire mem_we_i1,
//    input wire [`RegBus] mem_wdata_i1,
//    input wire [`RegAddrBus] mem_waddr_i1,
//    input wire mem_we_i2,
//    input wire [`RegBus] mem_wdata_i2,
//    input wire [`RegAddrBus] mem_waddr_i2,
    
    output wire load_dependency
//    output wire mem_dependency
);

    wire [5:0] op = inst_i[31:26];
    wire [4:0] rs = inst_i[25:21];
    wire [4:0] rt = inst_i[20:16];
    wire [4:0] rd = inst_i[15:11];
    wire [4:0] sa = inst_i[10:6];
    wire [5:0] funct = inst_i[5:0];
    wire [`RegBus] imm_zext = {16'h0, inst_i[15:0]};
    wire [`RegBus] imm_sext = {{16{inst_i[15]}}, inst_i[15:0]};
    wire [`RegBus] imm_jext = {4'h0, inst_i[25:0], 2'b00};
    wire [`RegBus] imm_bext = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};
        
    reg instvalid;  // 指示指令是否有效
    reg reg1_load_dependency;
    reg reg2_load_dependency;
//    reg reg1_mem_dependency;
//    reg reg2_mem_dependency;
    
    // 例外处理
    reg excepttype_is_syscall;
    reg excepttype_is_eret;
    reg excepttype_is_break;
    wire excepttype_is_adel;
    
    assign load_dependency = (reg1_load_dependency == `LoadDependent || 
                            reg2_load_dependency == `LoadDependent) ? 
                            `LoadDependent : `LoadIndependent;
//    assign mem_dependency = reg1_mem_dependency | reg2_mem_dependency;

  
    assign excepttype_is_adel = | inst_addr_i[1:0];
    
    assign excepttype_o = {17'b0, excepttype_is_eret, 3'b0, instvalid,
                            excepttype_is_break, excepttype_is_syscall, 
                            3'b0, excepttype_is_adel, 4'b0};                          
                            
// 第一段：对指令进行译码 
	always @ (*) begin	
		if (rst == `RstEnable || excepttype_is_adel) begin
			aluop_o = `EXE_NOP_OP;
			alusel_o = `EXE_RES_NOP;
			wd_o = `NOPRegAddr;
			wreg_o = `WriteDisable;
			instvalid = `InstValid;
			reg1_read_o = 1'b0;
			reg2_read_o = 1'b0;
			reg1_addr_o = `NOPRegAddr;
			reg2_addr_o = `NOPRegAddr;
			imm = 32'h0;	
			hi_re = `ReadDisable;
			lo_re = `ReadDisable;
			hi_we = `WriteDisable;
			lo_we = `WriteDisable;	
			is_md = 1'b0;	
			is_jb = 1'b0;
			is_ls = 1'b0;
			is_cp0 = 1'b0;
			is_bly = 1'b0;
			cp0_sel_o = 3'b000;
			cp0_addr_o = `NOPRegAddr;
			excepttype_is_syscall = `False_v;
            excepttype_is_eret = `False_v;
            excepttype_is_break = `False_v;
        end else begin
            aluop_o = `EXE_NOP_OP;
            alusel_o = `EXE_RES_NOP;
            wd_o = rd;
            wreg_o = `WriteDisable;
            instvalid = `InstInvalid;	   
            reg1_read_o = 1'b0;
            reg2_read_o = 1'b0;
            reg1_addr_o = rs;
            reg2_addr_o = rt;		
            imm = `ZeroWord;
            hi_re = `ReadDisable;
            lo_re = `ReadDisable;
            hi_we = `WriteDisable;
            lo_we = `WriteDisable;
            is_jb = 1'b0;
            is_ls = 1'b0;
            is_cp0 = 1'b0;
            is_md = 1'b0;
            is_bly = 1'b0;
            cp0_sel_o = 3'b000;
            cp0_addr_o = `NOPRegAddr;
            excepttype_is_syscall = `False_v;
            excepttype_is_eret = `False_v;
            excepttype_is_break = `False_v;
            case (op)
                `EXE_SPECIAL_INST:  begin
                    case (sa)
                        5'b00000:   begin
                            case (funct)
                                `EXE_OR:    begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_OR_OP;
                                    alusel_o = `EXE_RES_LOGIC;     
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;    
                                end  
                                `EXE_AND:    begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_AND_OP;
                                    alusel_o = `EXE_RES_LOGIC;      
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;    
                                    instvalid = `InstValid;    
                                end      
                                `EXE_XOR:    begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_XOR_OP;
                                    alusel_o = `EXE_RES_LOGIC;        
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;    
                                    instvalid = `InstValid;    
                                end                  
                                `EXE_NOR:    begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_NOR_OP;
                                    alusel_o = `EXE_RES_LOGIC;       
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;    
                                    instvalid = `InstValid;    
                                end 
                                `EXE_SLLV: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_SLL_OP;
                                    alusel_o = `EXE_RES_SHIFT;        
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;    
                                end 
                                `EXE_SRLV: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_SRL_OP;
                                    alusel_o = `EXE_RES_SHIFT;        
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;    
                                end                     
                                `EXE_SRAV: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_SRA_OP;
                                    alusel_o = `EXE_RES_SHIFT;        
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;            
                                end            
                                `EXE_SYNC: begin
                                    wreg_o = `WriteDisable;        
                                    aluop_o = `EXE_NOP_OP;
                                    alusel_o = `EXE_RES_NOP;        
                                    reg1_read_o = 1'b0;    
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;    
                                end
                                `EXE_MFHI: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_MFHI_OP;
                                    alusel_o = `EXE_RES_MOVE;   
                                    reg1_read_o = 1'b0;       
                                    reg2_read_o = 1'b0;
                                    instvalid = `InstValid;
                                    hi_re = `ReadEnable;    
                                end
                                `EXE_MFLO: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_MFLO_OP;
                                    alusel_o = `EXE_RES_MOVE;   
                                    reg1_read_o = 1'b0;    
                                    reg2_read_o = 1'b0;
                                    instvalid = `InstValid; 
                                    lo_re = `ReadEnable;   
                                end
                                `EXE_MTHI: begin
                                    wreg_o = `WriteDisable;        
                                    aluop_o = `EXE_MTHI_OP;
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b0; 
                                    instvalid = `InstValid;
                                    hi_we = `WriteEnable;    
                                end
                                `EXE_MTLO: begin
                                    wreg_o = `WriteDisable;        
                                    aluop_o = `EXE_MTLO_OP;
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b0; 
                                    instvalid = `InstValid;
                                    lo_we = `WriteEnable;    
                                end
                                // 条件移动由于ID的两个子部件存在数据相关问题，所以不能在此处立刻判断
                                // 因此先默认条件满足，再在执行阶段进一步判断
                                `EXE_MOVN: begin
                                    wreg_o = `WriteEnable;
                                    aluop_o = `EXE_MOVN_OP;
                                    alusel_o = `EXE_RES_MOVE;   
                                    reg1_read_o = 1'b1;   
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;
                                end
                                `EXE_MOVZ: begin
                                    wreg_o = `WriteEnable;  
                                    aluop_o = `EXE_MOVZ_OP;
                                    alusel_o = `EXE_RES_MOVE;   
                                    reg1_read_o = 1'b1;   
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;                     
                                end
                                `EXE_SLT: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_SLT_OP;
                                    alusel_o = `EXE_RES_ARITHMETIC;        
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;    
                                end
                                `EXE_SLTU: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_SLTU_OP;
                                    alusel_o = `EXE_RES_ARITHMETIC;        
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;  
                                    instvalid = `InstValid;    
                                end
                                `EXE_ADD: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_ADD_OP;
                                    alusel_o = `EXE_RES_ARITHMETIC;        
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;    
                                end
                                `EXE_ADDU: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_ADDU_OP;
                                    alusel_o = `EXE_RES_ARITHMETIC;        
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;    
                                end
                                `EXE_SUB: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_SUB_OP;
                                    alusel_o = `EXE_RES_ARITHMETIC;        
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;    
                                end
                                `EXE_SUBU: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_SUBU_OP;
                                    alusel_o = `EXE_RES_ARITHMETIC;        
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    instvalid = `InstValid;    
                                end
                                `EXE_MULT: begin
                                    wreg_o = `WriteDisable;        
                                    aluop_o = `EXE_MULT_OP;
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    is_md = 1'b1; 
                                    instvalid = `InstValid;
                                    hi_we = `WriteEnable;
                                    lo_we = `WriteEnable;    
                                end
                                `EXE_MULTU: begin
                                    wreg_o = `WriteDisable;        
                                    aluop_o = `EXE_MULTU_OP;
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1;
                                    is_md = 1'b1; 
                                    instvalid = `InstValid;
                                    hi_we = `WriteEnable;
                                    lo_we = `WriteEnable;    
                                end
                                `EXE_DIV: begin
                                    wreg_o = `WriteDisable;        
                                    aluop_o = `EXE_DIV_OP;
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1; 
                                    instvalid = `InstValid;
                                    hi_we = `WriteEnable;
                                    lo_we = `WriteEnable;
                                    is_md = 1'b1;    
                                end
                                `EXE_DIVU: begin
                                    wreg_o = `WriteDisable;        
                                    aluop_o = `EXE_DIVU_OP;
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b1; 
                                    instvalid = `InstValid; 
                                    hi_we = `WriteEnable;
                                    lo_we = `WriteEnable;
                                    is_md = 1'b1;   
                                end
                                `EXE_JR: begin
                                    wreg_o = `WriteDisable;       
                                    aluop_o = `EXE_JR_OP;
                                    alusel_o = `EXE_RES_JUMP_BRANCH;   
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b0;
                                    instvalid = `InstValid;
                                    is_jb = 1'b1;    
                                end
                                `EXE_JALR: begin
                                    wreg_o = `WriteEnable;        
                                    aluop_o = `EXE_JALR_OP;
                                    alusel_o = `EXE_RES_JUMP_BRANCH;   
                                    reg1_read_o = 1'b1;    
                                    reg2_read_o = 1'b0;
                                    wd_o = rd;
                                    instvalid = `InstValid;
                                    is_jb = 1'b1;    
                                end                                                                                                         
                                default: ;
                            endcase  // case funct
                        end
                        default: ;
                    endcase  // case sa
                    case (funct)
                        `EXE_TEQ: begin
                            wreg_o = `WriteDisable;
                            aluop_o = `EXE_TEQ_OP;
                            alusel_o = `EXE_RES_NOP;   
                            reg1_read_o = 1'b0;    
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                        end
                        `EXE_TGE: begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TGE_OP;
                            alusel_o = `EXE_RES_NOP;   
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b1;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                        end        
                        `EXE_TGEU: begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TGEU_OP;
                            alusel_o = `EXE_RES_NOP;   
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b1;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                        end    
                        `EXE_TLT: begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TLT_OP;
                            alusel_o = `EXE_RES_NOP;   
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b1;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                        end
                        `EXE_TLTU: begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TLTU_OP;
                            alusel_o = `EXE_RES_NOP;   
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b1;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                        end    
                        `EXE_TNE: begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TNE_OP;
                            alusel_o = `EXE_RES_NOP;   
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b1;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                        end
                        `EXE_SYSCALL: begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_SYSCALL_OP;
                            alusel_o = `EXE_RES_NOP;   
                            reg1_read_o = 1'b0;    
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid; 
                            excepttype_is_syscall= `True_v;
                            is_cp0 = 1'b1;
                        end
                        `EXE_BREAK: begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_BREAK_OP;
                            alusel_o = `EXE_RES_NOP;   
                            reg1_read_o = 1'b0;    
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;
                            excepttype_is_break = `True_v;
                            is_cp0 = 1'b1;
                        end                                                                                                                 
                        default:    begin
                        end    
                    endcase // case funct                                   
                end                                      
                `EXE_ORI:   begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_OR_OP;
                    alusel_o = `EXE_RES_LOGIC; 
                    reg1_read_o = 1'b1;   
                    reg2_read_o = 1'b0;          
                    imm = imm_zext;        
                    wd_o = rt;
                    instvalid = `InstValid;    
                end
                `EXE_ANDI:    begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_AND_OP;
                    alusel_o = `EXE_RES_LOGIC;   
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    imm = imm_zext;      
                    wd_o = rt;              
                    instvalid = `InstValid;    
                end         
                `EXE_XORI:    begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_XOR_OP;
                    alusel_o = `EXE_RES_LOGIC;    
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    imm = imm_zext;        
                    wd_o = rt;              
                    instvalid = `InstValid;    
                end             
                `EXE_LUI:     begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_OR_OP;
                    alusel_o = `EXE_RES_LOGIC; 
                    reg1_read_o = 1'b1;   
                    reg2_read_o = 1'b0;          
                    imm = {inst_i[15:0], 16'h0};    
                    wd_o = rt;              
                    instvalid = `InstValid;    
                end
                `EXE_SLTI:      begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_SLT_OP;
                    alusel_o = `EXE_RES_ARITHMETIC; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    imm = imm_sext;        
                    wd_o = rt;              
                    instvalid = `InstValid;    
                end
                `EXE_SLTIU:     begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_SLTU_OP;
                    alusel_o = `EXE_RES_ARITHMETIC; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    imm = imm_sext;        
                    wd_o = rt;              
                    instvalid = `InstValid;    
                end
                `EXE_ADDI:      begin
                    wreg_o = `WriteEnable;       
                    aluop_o = `EXE_ADDI_OP;
                    alusel_o = `EXE_RES_ARITHMETIC; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    imm = imm_sext;       
                    wd_o = rt;              
                    instvalid = `InstValid;    
                end
                `EXE_ADDIU:     begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_ADDIU_OP;
                    alusel_o = `EXE_RES_ARITHMETIC; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    imm = imm_sext;        
                    wd_o = rt;              
                    instvalid = `InstValid;    
                end
                `EXE_J:         begin
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_J_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o = 1'b0;    
                    reg2_read_o = 1'b0;
                    instvalid = `InstValid;    
                    is_jb = 1'b1;
                    imm = imm_jext;
                end
                `EXE_JAL:       begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_JAL_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o = 1'b0;    
                    reg2_read_o = 1'b0;
                    wd_o = 5'b11111;    
                    instvalid = `InstValid;    
                    is_jb = 1'b1;
                    imm = imm_jext;
                end
                `EXE_BEQ:       begin
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_BEQ_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b1;
                    instvalid = `InstValid;    
                    is_jb = 1'b1; 
                    imm = imm_bext;             
                end
                `EXE_BEQL:      begin
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_BEQ_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b1;
                    instvalid = `InstValid;    
                    is_jb = 1'b1;
                    is_bly = 1'b1; 
                    imm = imm_bext;             
                end
                `EXE_BGTZ:      begin
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_BGTZ_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;
                    instvalid = `InstValid;    
                    is_jb = 1'b1;
                    imm = imm_bext;            
                end
                `EXE_BGTZL:     begin
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_BGTZ_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;
                    instvalid = `InstValid;    
                    is_jb = 1'b1;
                    is_bly = 1'b1;
                    imm = imm_bext;            
                end
                `EXE_BLEZ:      begin
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_BLEZ_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;
                    instvalid = `InstValid;    
                    is_jb = 1'b1;
                    imm = imm_bext;            
                end
                `EXE_BLEZL:      begin
                    if (~|rt) begin
                        wreg_o = `WriteDisable;        
                        aluop_o = `EXE_BLEZ_OP;
                        alusel_o = `EXE_RES_JUMP_BRANCH; 
                        reg1_read_o = 1'b1;    
                        reg2_read_o = 1'b0;
                        instvalid = `InstValid;    
                        is_jb = 1'b1;
                        is_bly = 1'b1;
                        imm = imm_bext;     
                    end else begin
                        wreg_o = `WriteDisable;
                        aluop_o = `EXE_NOP_OP;
                        alusel_o = `EXE_RES_NOP;
                        reg1_read_o = 1'b0;
                        reg2_read_o = 1'b0;
                        instvalid = `InstInvalid;
                    end
                end
                `EXE_BNE:       begin
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_BNE_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b1;
                    instvalid = `InstValid;    
                    is_jb = 1'b1; 
                    imm = imm_bext;             
                end
                `EXE_BNEL:       begin
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_BNE_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b1;
                    instvalid = `InstValid;    
                    is_jb = 1'b1; 
                    is_bly = 1'b1;
                    imm = imm_bext;             
                end
                `EXE_LB:        begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_LB_OP;
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    wd_o = rt; 
                    instvalid = `InstValid; 
                    is_ls = 1'b1;   
                    imm = imm_sext;
                end
                `EXE_LBU:       begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_LBU_OP;
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    wd_o = rt; 
                    instvalid = `InstValid;   
                    is_ls = 1'b1; 
                    imm = imm_sext;
                end
                `EXE_LH:        begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_LH_OP;
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    wd_o = rt; 
                    instvalid = `InstValid;  
                    is_ls = 1'b1;  
                    imm = imm_sext;
                end
                `EXE_LHU:       begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_LHU_OP;
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    wd_o = rt; 
                    instvalid = `InstValid; 
                    is_ls = 1'b1;   
                    imm = imm_sext;
                end
                `EXE_LW:        begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_LW_OP;
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    wd_o = rt; 
                    instvalid = `InstValid; 
                    is_ls = 1'b1;   
                    imm = imm_sext;
                end
                `EXE_LWL:       begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_LWL_OP;
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b1;          
                    wd_o = rt; 
                    instvalid = `InstValid;
                    is_ls = 1'b1;    
                    imm = imm_sext;
                end
                `EXE_LWR:       begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_LWR_OP;
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b1;          
                    wd_o = rt; 
                    instvalid = `InstValid; 
                    is_ls = 1'b1;   
                    imm = imm_sext;
                end
                `EXE_SB:        begin
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_SB_OP;
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b1; 
                    instvalid = `InstValid; 
                    is_ls = 1'b1;   
                    imm = imm_sext;
                end
                `EXE_SH:        begin
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_SH_OP;
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b1; 
                    instvalid = `InstValid;    
                    is_ls = 1'b1;
                    imm = imm_sext;
                end
                `EXE_SW:        begin
                    alusel_o = `EXE_RES_LOAD_STORE;
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_SW_OP;
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b1; 
                    instvalid = `InstValid;    
                    is_ls = 1'b1;
                    imm = imm_sext;
                end
                `EXE_SWL:       begin
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_SWL_OP;
                    reg1_read_o = 1'b1;   
                    reg2_read_o = 1'b1; 
                    instvalid = `InstValid; 
                    is_ls = 1'b1;   
                    imm = imm_sext;
                end
                `EXE_SWR:       begin
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_SWR_OP;
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b1; 
                    instvalid = `InstValid;
                    is_ls = 1'b1; 
                    imm = imm_sext;
                end
                `EXE_LL:        begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_LL_OP;
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    reg1_read_o = 1'b1;    
                    reg2_read_o = 1'b0;          
                    wd_o = rt; 
                    instvalid = `InstValid;
                    is_ls = 1'b1;
                    imm = imm_sext;
                end
                `EXE_SC:        begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_SC_OP;
                    alusel_o = `EXE_RES_LOAD_STORE; 
                    reg1_read_o = 1'b1;   
                    reg2_read_o = 1'b1;          
                    wd_o = rt; 
                    instvalid = `InstValid; 
                    is_ls = 1'b1;
                    imm = imm_sext;   
                end        
                `EXE_PREF:      begin
                    wreg_o = `WriteDisable;        
                    aluop_o = `EXE_NOP_OP;
                    alusel_o = `EXE_RES_NOP; 
                    reg1_read_o = 1'b0;    
                    reg2_read_o = 1'b0;                
                    instvalid = `InstValid;    
                end
                `EXE_REGIMM_INST:   begin
                    case (rt)
                        `EXE_BGEZ:  begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_BGEZ_OP;
                            alusel_o = `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;    
                            is_jb = 1'b1;
                            imm = imm_bext;              
                        end
                        `EXE_BGEZL:  begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_BGEZ_OP;
                            alusel_o = `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;    
                            is_jb = 1'b1;
                            is_bly = 1'b1;
                            imm = imm_bext;              
                        end
                        `EXE_BGEZAL:    begin
                            wreg_o = `WriteEnable;        
                            aluop_o = `EXE_BGEZAL_OP;
                            alusel_o = `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;
                            wd_o = 5'b11111;      
                            instvalid = `InstValid;
                            is_jb = 1'b1;
                            imm = imm_bext;
                        end
                        `EXE_BGEZALL:    begin
                            wreg_o = `WriteEnable;        
                            aluop_o = `EXE_BGEZAL_OP;
                            alusel_o = `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;
                            wd_o = 5'b11111;      
                            instvalid = `InstValid;
                            is_jb = 1'b1;
                            is_bly = 1'b1;
                            imm = imm_bext;
                        end
                        `EXE_BLTZ:      begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_BLTZ_OP;
                            alusel_o = `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;    
                            is_jb = 1'b1;
                            imm = imm_bext;              
                        end
                        `EXE_BLTZL:      begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_BLTZ_OP;
                            alusel_o = `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;    
                            is_jb = 1'b1;
                            is_bly = 1'b1;
                            imm = imm_bext;              
                        end
                        `EXE_BLTZAL:        begin
                            wreg_o = `WriteEnable;        
                            aluop_o = `EXE_BLTZAL_OP;
                            alusel_o = `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;
                            wd_o = 5'b11111; 
                            instvalid = `InstValid;
                            is_jb = 1'b1;
                            imm = imm_bext;
                        end
                        `EXE_BLTZALL:        begin
                            wreg_o = `WriteEnable;        
                            aluop_o = `EXE_BLTZAL_OP;
                            alusel_o = `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;
                            wd_o = 5'b11111; 
                            instvalid = `InstValid;
                            is_jb = 1'b1;
                            is_bly = 1'b1;
                            imm = imm_bext;
                        end
                        `EXE_TEQI:          begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TEQI_OP;
                            alusel_o = `EXE_RES_NOP; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;          
                            imm = imm_sext;              
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;    
                        end
                        `EXE_TGEI:          begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TGEI_OP;
                            alusel_o = `EXE_RES_NOP; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;          
                            imm = imm_sext;              
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;      
                        end
                        `EXE_TGEIU:         begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TGEIU_OP;
                            alusel_o = `EXE_RES_NOP; 
                            reg1_read_o = 1'b1;   
                            reg2_read_o = 1'b0;          
                            imm = imm_sext;              
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;      
                        end
                        `EXE_TLTI:          begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TLTI_OP;
                            alusel_o = `EXE_RES_NOP; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;          
                            imm = imm_sext;              
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;      
                        end
                        `EXE_TLTIU:         begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TLTIU_OP;
                            alusel_o = `EXE_RES_NOP;
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;          
                            imm = imm_sext;              
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;      
                        end
                        `EXE_TNEI:          begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_TNEI_OP;
                            alusel_o = `EXE_RES_NOP; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;          
                            imm = imm_sext;              
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;      
                        end
                        default:    ;
                    endcase  // case op4
                end
                `EXE_SPECIAL2_INST:     begin
                    case (funct)
                        `EXE_CLZ:       begin
                            wreg_o = `WriteEnable;        
                            aluop_o = `EXE_CLZ_OP;
                            alusel_o = `EXE_RES_ARITHMETIC; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;          
                            instvalid = `InstValid;    
                        end
                        `EXE_CLO:        begin
                            wreg_o = `WriteEnable;        
                            aluop_o = `EXE_CLO_OP;
                            alusel_o = `EXE_RES_ARITHMETIC;
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b0;          
                            instvalid = `InstValid;    
                        end
                        `EXE_MUL:        begin
                            wreg_o = `WriteEnable;        
                            aluop_o = `EXE_MUL_OP;
                            alusel_o = `EXE_RES_MUL; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b1;
                            is_md = 1'b1;    
                            instvalid = `InstValid;                  
                        end
                        `EXE_MADD:      begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_MADD_OP;
                            alusel_o = `EXE_RES_MUL; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b1;                  
                            instvalid = `InstValid;
                            is_md = 1'b1;
                            hi_re = 1'b1;
                            hi_we = 1'b1;
                            lo_re = 1'b1;
                            lo_we = 1'b1;    
                        end
                        `EXE_MADDU:     begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_MADDU_OP;
                            alusel_o = `EXE_RES_MUL; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b1;                  
                            instvalid = `InstValid;
                            is_md = 1'b1;
                            hi_re = 1'b1;
                            hi_we = 1'b1;
                            lo_re = 1'b1;
                            lo_we = 1'b1;    
                        end
                        `EXE_MSUB:      begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_MSUB_OP;
                            alusel_o = `EXE_RES_MUL; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b1;                  
                            instvalid = `InstValid;
                            is_md = 1'b1;
                            hi_re = 1'b1;
                            hi_we = 1'b1;
                            lo_re = 1'b1;
                            lo_we = 1'b1;    
                        end
                        `EXE_MSUBU:     begin
                            wreg_o = `WriteDisable;        
                            aluop_o = `EXE_MSUBU_OP;
                            alusel_o = `EXE_RES_MUL; 
                            reg1_read_o = 1'b1;    
                            reg2_read_o = 1'b1;                  
                            instvalid = `InstValid;
                            is_md = 1'b1;
                            hi_re = 1'b1;
                            hi_we = 1'b1;
                            lo_re = 1'b1;
                            lo_we = 1'b1;    
                        end
                        default: ;
                    endcase      //case EXE_SPECIAL_INST2
                end
                `EXE_CACHE:         begin
                    case(rt)
                        `EXE_III:   begin
                            aluop_o = `EXE_III_OP;
                            alusel_o = `EXE_RES_NOP;
                            wreg_o = `WriteDisable;
                            reg1_read_o = 1'b1;
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                            imm = imm_sext;
                        end
                        `EXE_IIST:  begin
                            aluop_o = `EXE_IIST_OP;
                            alusel_o = `EXE_RES_NOP;
                            wreg_o = `WriteDisable;
                            reg1_read_o = 1'b1;
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                            imm = imm_sext;
                            cp0_sel_o = 3'b0;
                            cp0_addr_o = `CP0_REG_TagLo;
                        end
                        `EXE_IHI:   begin
                            aluop_o = `EXE_IHI_OP;
                            alusel_o = `EXE_RES_NOP;
                            wreg_o = `WriteDisable;
                            reg1_read_o = 1'b1;
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                            imm = imm_sext;
                        end
                        `EXE_DIWI:  begin
                            aluop_o = `EXE_DIWI_OP;
                            alusel_o = `EXE_RES_NOP;
                            wreg_o = `WriteDisable;
                            reg1_read_o = 1'b1;
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                            is_ls = 1'b1;
                            imm = imm_sext;
                        end
                        `EXE_DIST:  begin
                            aluop_o = `EXE_DIST_OP;
                            alusel_o = `EXE_RES_NOP;
                            wreg_o = `WriteDisable;
                            reg1_read_o = 1'b1;
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                            is_ls = 1'b1;
                            imm = imm_sext;
                            cp0_sel_o = 3'b0;
                            cp0_addr_o = `CP0_REG_TagLo;
                        end
                        `EXE_DHI:   begin
                            aluop_o = `EXE_DHI_OP;
                            alusel_o = `EXE_RES_NOP;
                            wreg_o = `WriteDisable;
                            reg1_read_o = 1'b1;
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                            is_ls = 1'b1;
                            imm = imm_sext;
                        end
                        `EXE_DHWI:  begin
                            aluop_o = `EXE_DHWI_OP;
                            alusel_o = `EXE_RES_NOP;
                            wreg_o = `WriteDisable;
                            reg1_read_o = 1'b1;
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;
                            is_cp0 = 1'b1;
                            is_ls = 1'b1;
                            imm = imm_sext;
                        end
                        default:    begin
                            aluop_o = `EXE_NOP_OP;
                            alusel_o = `EXE_RES_NOP;
                            wreg_o = `WriteDisable;
                            reg1_read_o = 1'b0;
                            reg2_read_o = 1'b0;
                            instvalid = `InstValid;
                        end
                    endcase
                end       
                `EXE_COP0:          begin
                    if(rs == 5'b00000 && ~|inst_i[10:3]) begin
                        aluop_o = `EXE_MFC0_OP;
                        alusel_o = `EXE_RES_MOVE;
                        wd_o = rt;
                        wreg_o = `WriteEnable;
                        instvalid = `InstValid;       
                        reg1_read_o = 1'b0;
                        reg2_read_o = 1'b0;
                        is_cp0 = 1'b1;
                        cp0_sel_o = inst_i[2:0]; 
                        cp0_addr_o = rd;       
                    end else if(rs == 5'b00100 && ~|inst_i[10:3]) begin
                        aluop_o = `EXE_MTC0_OP;
                        alusel_o = `EXE_RES_NOP;
                        wreg_o = `WriteDisable;
                        instvalid = `InstValid;       
                        reg1_read_o = 1'b1;
                        reg2_read_o = 1'b0;     
                        reg1_addr_o = rt;
                        is_cp0 = 1'b1;
                        cp0_sel_o = inst_i[2:0];
                        cp0_addr_o = rd;                 
                    end
                end
                default: ;
            endcase  //case op
            if (inst_i == `EXE_ERET) begin
                wreg_o = `WriteDisable;        
                aluop_o = `EXE_ERET_OP;
                alusel_o = `EXE_RES_NOP; 
                reg1_read_o = 1'b0;    
                reg2_read_o = 1'b0;    
                instvalid = `InstValid;
                excepttype_is_eret = `True_v;
                is_cp0 = 1'b1;
            end
            if (inst_i[31:21] == 11'b00000000000) begin
                if (funct == `EXE_SLL) begin
                    wreg_o = |rd;        
                    aluop_o = `EXE_SLL_OP;
                    alusel_o = `EXE_RES_SHIFT; 
                    reg1_read_o = 1'b0;   
                    reg2_read_o = 1'b1;          
                    imm[4:0] = sa;     
                    wd_o = rd;
                    instvalid = `InstValid;    
                end else if (funct == `EXE_SRL) begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_SRL_OP;
                    alusel_o = `EXE_RES_SHIFT;
                    reg1_read_o = 1'b0;   
                    reg2_read_o = 1'b1;          
                    imm[4:0] = sa;      
                    wd_o = rd;
                    instvalid = `InstValid;    
                end else if (funct == `EXE_SRA) begin
                    wreg_o = `WriteEnable;        
                    aluop_o = `EXE_SRA_OP;
                    alusel_o = `EXE_RES_SHIFT; 
                    reg1_read_o = 1'b0;    
                    reg2_read_o = 1'b1;          
                    imm[4:0] = sa;        
                    wd_o = rd;
                    instvalid = `InstValid;    
                end
            end                   
        end       //if
    end         //always
	
// 第二段：确定进行运算的源操作数1
//    always @ (*) begin
//        reg1_load_dependency = `LoadIndependent;
////        reg1_mem_dependency = 1'b0;
//        if(rst == `RstEnable)
//            reg1_o = `ZeroWord;
//        else if((reg1_read_o == 1'b1) && (ex_waddr_i1 == reg1_addr_o)
//                && (pre_inst_is_load == 1'b1)) begin
//            reg1_load_dependency = `LoadDependent;
//            reg1_o = `ZeroWord;
//        end else if((reg1_read_o == 1'b1) && (ex_we_i2 == 1'b1) 
//                    && (ex_waddr_i2 == reg1_addr_o))
//            reg1_o = ex_wdata_i2; 
//        else if((reg1_read_o == 1'b1) && (ex_we_i1 == 1'b1) 
//                    && (ex_waddr_i1 == reg1_addr_o))
//            reg1_o = ex_wdata_i1; 
//        else if((reg1_read_o == 1'b1) && (mem_we_i2 == 1'b1) 
//                    && (mem_waddr_i2 == reg1_addr_o)) begin
//            reg1_o = mem_wdata_i2;
////            reg1_o = `ZeroWord;
////            reg1_mem_dependency = 1'b1;
//        end else if((reg1_read_o == 1'b1) && (mem_we_i1 == 1'b1) 
//                    && (mem_waddr_i1 == reg1_addr_o)) begin
//            reg1_o = mem_wdata_i1;
////            reg1_o = `ZeroWord;
////            reg1_mem_dependency = 1'b1;
//        end else if(reg1_read_o == 1'b1)
//            reg1_o = reg1_data_i;
//        else if(reg1_read_o == 1'b0)
//            reg1_o = imm;
//        else
//            reg1_o = `ZeroWord;
//    end

    always @(*) begin
        if((reg1_read_o == 1'b1) && (ex_waddr_i1 == reg1_addr_o) && (pre_inst_is_load == 1'b1))
            reg1_load_dependency = `LoadDependent;
        else 
            reg1_load_dependency = `LoadIndependent;
    end

// 第三段：确定进行运算的源操作数2	
//    always @ (*) begin
//        reg2_load_dependency = `LoadIndependent;
////        reg2_mem_dependency = 1'b0;
//        if(rst == `RstEnable)
//            reg2_o = `ZeroWord;      
//        else if((reg2_read_o == 1'b1) && (ex_waddr_i1 == reg2_addr_o)
//                && (pre_inst_is_load == 1'b1)) begin
//            reg2_load_dependency = `LoadDependent;
//            reg2_o = `ZeroWord;
//        end else if((reg2_read_o == 1'b1) && (ex_we_i2 == 1'b1) 
//                    && (ex_waddr_i2 == reg2_addr_o))
//            reg2_o = ex_wdata_i2; 
//        else if((reg2_read_o == 1'b1) && (ex_we_i1 == 1'b1) 
//                    && (ex_waddr_i1 == reg2_addr_o))
//            reg2_o = ex_wdata_i1; 
//        else if((reg2_read_o == 1'b1) && (mem_we_i2 == 1'b1) 
//                    && (mem_waddr_i2 == reg2_addr_o)) begin
//            reg2_o = mem_wdata_i2;
////            reg2_o = `ZeroWord;
////            reg2_mem_dependency = 1'b1;
//        end else if((reg2_read_o == 1'b1) && (mem_we_i1 == 1'b1) 
//                    && (mem_waddr_i1 == reg2_addr_o)) begin
//            reg2_o = mem_wdata_i1;
////            reg2_o = `ZeroWord;
////            reg2_mem_dependency = 1'b1;
//        end else if(reg2_read_o == 1'b1)
//            reg2_o = reg2_data_i;
//        else if(reg2_read_o == 1'b0)
//            reg2_o = imm;
//        else
//            reg2_o = `ZeroWord;
//    end

    always @ (*) begin
        if((reg2_read_o == 1'b1) && (ex_waddr_i1 == reg2_addr_o) && (pre_inst_is_load == 1'b1))
            reg2_load_dependency = `LoadDependent;
        else 
            reg2_load_dependency = `LoadIndependent;
    end

endmodule
