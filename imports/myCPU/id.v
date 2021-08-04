`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/09 22:51:24
// Design Name: 
// Module Name: id
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

`include "defines.v"
module id(
    input wire clk,
    input wire rst,
    input wire stallreq_from_ex,
    input wire stallreq_from_dcache,
    
    input wire issue_en1,
	input wire [`InstAddrBus] inst_addr_i1,  // 译码阶段的指令对应的地址
	input wire [`InstAddrBus] inst_addr_i2,
	input wire [`InstBus] inst_i1,  // 译码阶段的指令
    input wire [`InstBus] inst_i2,
    input wire [`BPBPacketWidth] predict_pkt,
    input wire pre_inst_is_bly,
    input wire ex_branch_flag,
    
    // 读取的regfile的值
//	input wire [`RegBus] reg1_data_i1,  // 从regfile输入的第一个读端口的输出
//	input wire [`RegBus] reg2_data_i1,
//    input wire [`RegBus] reg1_data_i2,
//    input wire [`RegBus] reg2_data_i2,
    
	//送到regfile的信息
	output wire reg1_read_o1,  // regfile的第一个读端口的读使能信号
	output wire reg2_read_o1,
	output wire reg1_read_o2,
	output wire reg2_read_o2,
	     
	output wire [`RegAddrBus] reg1_addr_o1,  // regfile的第一个读端口的读地址信号
	output wire [`RegAddrBus] reg2_addr_o1,
	output wire [`RegAddrBus] reg1_addr_o2,
	output wire [`RegAddrBus] reg2_addr_o2, 	      
	
	// 送到执行阶段的信息
    output reg [`BPBPacketWidth] predict_pkt_o,
    output reg [2:0] cp0_sel_o,
    output reg [`RegAddrBus] cp0_addr_o,
    output reg is_bly1,  // 是否是branch_likely指令
    
	// 第一条指令的信息
    output reg [`RegBus] imm_o1,
	output reg [`AluOpBus] aluop_o1,
	output reg [`AluSelBus] alusel_o1,
//	output reg [`RegBus] reg1_o1,  // 源操作数1
//	output reg [`RegBus] reg2_o1,
	output reg [`RegAddrBus] wd_o1,  // 要写入的目的寄存器的地址
	output reg wreg_o1,  // 是否有要写入的目的寄存器
	output reg [`InstAddrBus] inst_addr_o1,
	output reg [31:0] excepttype_o1,
	
	// 第二条指令的信息
	output wire [`RegBus] imm_o2,
	output reg [`AluOpBus] aluop_o2,
    output reg [`AluSelBus] alusel_o2,
//    output reg [`RegBus] reg1_o2,
//    output reg [`RegBus] reg2_o2,
    output reg [`RegAddrBus] wd_o2,
    output reg wreg_o2,
    output reg [`InstAddrBus] inst_addr_o2,
    output reg [31:0] excepttype_o2,
    
// 解决数据相关问题
    // 处于执行阶段的指令要写入的目的寄存器信息
//    input wire ex_we_i1,
//    input wire [`RegBus] ex_wdata_i1,
    input wire [`RegAddrBus] ex_waddr_i1,
//    input wire ex_we_i2,
//    input wire [`RegBus] ex_wdata_i2,
    input wire [`RegAddrBus] ex_waddr_i2,
        
    // 处于访存阶段的指令要写入的目的寄存器信息
//    input wire mem_we_i1,
//    input wire [`RegBus] mem_wdata_i1,
//    input wire [`RegAddrBus] mem_waddr_i1,
//    input wire mem_we_i2,
//    input wire [`RegBus] mem_wdata_i2,
//    input wire [`RegAddrBus] mem_waddr_i2,
    
    // 访存指令带来的数据相关问题
    input wire [`AluOpBus] ex_aluop_i1,
    
    // 转移指令设置
    input wire is_in_delayslot_i,  // 指令1是否是延迟槽指令
    output reg is_in_delayslot_o1,  // 指令1是否是延迟槽指令
    output reg is_in_delayslot_o2,  // 指令2是否是延迟槽指令
    output wire next_inst_in_delayslot,  // 下一条指令1是否是延迟槽指令
    
    // 发射模式设置
    output reg issue_mode,
    output reg issue_o,
    
    output reg stallreq_from_id
    );
    
    // 暂时存储第一条指令的信息
    wire [`AluOpBus] aluop_o1_temp;
    wire [`AluSelBus] alusel_o1_temp;
//    wire [`RegBus] reg1_o1_temp;
//    wire [`RegBus] reg2_o1_temp;
    wire [`RegAddrBus] wd_o1_temp;
    wire wreg_o1_temp;
    wire [31:0] excepttype_o1_temp;
	wire [`RegBus] imm_temp;
    wire [2:0] cp0_sel_o_temp;
    wire [`RegAddrBus] cp0_addr_o_temp;
    
    // 暂时存储第二条指令的信息
    wire [`AluOpBus] aluop_o2_temp;
    wire [`AluSelBus] alusel_o2_temp;
//    wire [`RegBus] reg1_o2_temp;
//    wire [`RegBus] reg2_o2_temp;
    wire [`RegAddrBus] wd_o2_temp;
    wire wreg_o2_temp;
    wire [31:0] excepttype_o2_temp;
    
    // 存储两个译码子部件对hi、lo寄存器的读写信息
    wire hi_re1, hi_we1, lo_re1, lo_we1;
    wire hi_re2, hi_we2, lo_re2, lo_we2;
    
    // 指令信息
    wire is_md1, is_md2;  // 是否是乘除法指令
    wire is_jb1;
    wire is_jb2;  // 是否是转移指令
    wire is_ls1, is_ls2;  // 是否是访存指令
    wire is_cp01, is_cp02;  // 是否是特权指令
    wire is_bly1_temp;  // 指令1是否是branch_likely指令
    wire pre_inst_is_load;  // 上一次指令是否是加载指令
    
    // 两个译码子部件之间是否存在数据相关
    reg reg3_raw;
    reg reg4_raw;
    reg hilo_raw;
    wire load_dependency;
    wire reg12_load_dependency;
    wire reg34_load_dependency;
//    wire mem_dependency;
//    wire reg12_mem_dependency;
//    wire reg34_mem_dependency;
   
    // 如果指令1是转移指令且单发射，则下一条指令1是延迟槽指令
    assign next_inst_in_delayslot = (is_jb1 == 1'b1 && issue_mode == `SingleIssue) ? 
                                    `InDelaySlot : `NotInDelaySlot;
                                    
    assign pre_inst_is_load = ((ex_aluop_i1 == `EXE_LB_OP) | 
                                (ex_aluop_i1 == `EXE_LBU_OP)|
                                (ex_aluop_i1 == `EXE_LH_OP) |
                                (ex_aluop_i1 == `EXE_LHU_OP)|
                                (ex_aluop_i1 == `EXE_LW_OP) |
                                (ex_aluop_i1 == `EXE_LWR_OP)|
                                (ex_aluop_i1 == `EXE_LWL_OP)|
                                (ex_aluop_i1 == `EXE_LL_OP) |
                                (ex_aluop_i1 == `EXE_SC_OP));

    assign load_dependency = (reg12_load_dependency == `LoadDependent || 
                              reg34_load_dependency == `LoadDependent) ? 
                              `LoadDependent : `LoadIndependent;
//    assign mem_dependency = reg12_mem_dependency | reg34_mem_dependency;
    
    id_sub id_sub1(
        .clk(clk),
        .rst(rst),
        .inst_addr_i(inst_addr_i1),
        .inst_i(inst_i1),
//        .reg1_data_i(reg1_data_i1),
//        .reg2_data_i(reg2_data_i1),
        // 送到regfile的信息
        .reg1_read_o(reg1_read_o1),
        .reg2_read_o(reg2_read_o1),       
        .reg1_addr_o(reg1_addr_o1),
        .reg2_addr_o(reg2_addr_o1),       
        // 送到ID/EX模块的信息
        .aluop_o(aluop_o1_temp),
        .alusel_o(alusel_o1_temp),
//        .reg1_o(reg1_o1_temp),
//        .reg2_o(reg2_o1_temp),
        .wd_o(wd_o1_temp),
        .wreg_o(wreg_o1_temp),
        .imm(imm_temp),
        .cp0_sel_o(cp0_sel_o_temp),
        .cp0_addr_o(cp0_addr_o_temp),
        .excepttype_o(excepttype_o1_temp),
        // 对hi、lo寄存器的读写信息
        .hi_re(hi_re1),
        .lo_re(lo_re1),
        .hi_we(hi_we1),
        .lo_we(lo_we1),
        // 指令信息
        .is_jb(is_jb1),
        .is_ls(is_ls1),
        .is_cp0(is_cp01),
        .is_md(is_md1),
        .is_bly(is_bly1_temp),
        .pre_inst_is_load(pre_inst_is_load),
        // 解决数据相关问题
        .ex_waddr_i1(ex_waddr_i1),
        .ex_waddr_i2(ex_waddr_i2),
//        .ex_we_i1(ex_we_i1),
//        .ex_we_i2(ex_we_i2),
//        .ex_wdata_i1(ex_wdata_i1),
//        .ex_wdata_i2(ex_wdata_i2),
//        .mem_waddr_i1(mem_waddr_i1),
//        .mem_waddr_i2(mem_waddr_i2),
//        .mem_we_i1(mem_we_i1),
//        .mem_we_i2(mem_we_i2),
//        .mem_wdata_i1(mem_wdata_i1),
//        .mem_wdata_i2(mem_wdata_i2),       
        .load_dependency(reg12_load_dependency)
//        .mem_dependency(reg12_mem_dependency)
    );
    
    id_sub id_sub2(
        .clk(clk),
        .rst(rst),
        .inst_addr_i(inst_addr_i2),
        .inst_i(inst_i2),
//        .reg1_data_i(reg1_data_i2),
//        .reg2_data_i(reg2_data_i2),
        //送到regfile的信息
        .reg1_read_o(reg1_read_o2),
        .reg2_read_o(reg2_read_o2),       
        .reg1_addr_o(reg1_addr_o2),
        .reg2_addr_o(reg2_addr_o2),       
        //送到ID/EX模块的信息
        .aluop_o(aluop_o2_temp),
        .alusel_o(alusel_o2_temp),
//        .reg1_o(reg1_o2_temp),
//        .reg2_o(reg2_o2_temp),
        .wd_o(wd_o2_temp),
        .wreg_o(wreg_o2_temp),
        .imm(imm_o2),
        .cp0_sel_o(),
        .cp0_addr_o(),
        .excepttype_o(excepttype_o2_temp),
        // 对hi、lo寄存器的读写信息
        .hi_re(hi_re2),
        .lo_re(lo_re2),
        .hi_we(hi_we2),
        .lo_we(lo_we2),
        // 指令信息
        .is_jb(is_jb2),
        .is_ls(is_ls2),
        .is_cp0(is_cp02),
        .is_md(is_md2),
        .is_bly(),
        .pre_inst_is_load(pre_inst_is_load),
        // 解决数据相关问题
        .ex_waddr_i1(ex_waddr_i1),
        .ex_waddr_i2(ex_waddr_i2),
//        .ex_we_i1(ex_we_i1),
//        .ex_we_i2(ex_we_i2),
//        .ex_wdata_i1(ex_wdata_i1),
//        .ex_wdata_i2(ex_wdata_i2),
//        .mem_waddr_i1(mem_waddr_i1),
//        .mem_waddr_i2(mem_waddr_i2),
//        .mem_we_i1(mem_we_i1),
//        .mem_we_i2(mem_we_i2),
//        .mem_wdata_i1(mem_wdata_i1),
//        .mem_wdata_i2(mem_wdata_i2),
        .load_dependency(reg34_load_dependency)
//        .mem_dependency(reg34_mem_dependency)
    );
    
// 第一段：RAW相关性检查
    always @ (*) begin
        if (rst == `RstEnable)
            reg3_raw = `RAWIndependent;  // 复位时设置为无数据相关 
        // 指令2的读端口1可读，指令1写入的地址为指令2的源寄存器1时RAW相关
        // 不加写地址不为0的话复位
        else if (wd_o1 != `RegNumLog2'h0 && reg1_read_o2 == `ReadEnable 
                && wreg_o1 == `WriteEnable && wd_o1 == reg1_addr_o2) 
            reg3_raw = `RAWDependent;
        else 
            reg3_raw = `RAWIndependent;
    end
    
    always @ (*) begin
        if (rst == `RstEnable) 
            reg4_raw = `RAWIndependent;
        else if (wd_o1 != `RegNumLog2'h0 && reg2_read_o2 == `ReadEnable 
                && wreg_o1 == `WriteEnable && wd_o1 == reg2_addr_o2) 
            reg4_raw = `RAWDependent;
        else 
            reg4_raw = `RAWIndependent;
    end

    always @ (*) begin
        if (rst == `RstEnable)
            hilo_raw = `RAWIndependent;
        else if (hi_we1 == `WriteEnable && hi_re2 == `ReadEnable)
            // HI寄存器数据相关
            hilo_raw = `RAWDependent;
        else if (lo_we1 == `WriteEnable && lo_re2 == `ReadEnable)
            // LO寄存器数据相关
            hilo_raw = `RAWDependent;
        else
            hilo_raw = `RAWIndependent;
    end
    
// 第二段：决定发射模式
    // 单发射还是双发射
    always @ (*) begin
        if (rst == `RstEnable)
            issue_mode = `DualIssue;
        else if (is_md1 | is_md2 | is_jb2 | is_in_delayslot_i | is_ls1 | is_ls2 | is_cp01 | is_cp02)
            issue_mode = `SingleIssue;
        else if (reg3_raw == `RAWDependent || reg4_raw == `RAWDependent || hilo_raw == `RAWDependent) 
            issue_mode = `SingleIssue;
        else 
            issue_mode = `DualIssue;
    end
    
    // 是否允许发射
    always @ (*) begin
        if (rst == `RstEnable || stallreq_from_ex == `Stop || stallreq_from_dcache == `Stop) begin
            issue_o = 1'b0;
            stallreq_from_id = `NoStop;
//        end else if (load_dependency == `LoadDependent || mem_dependency) begin
        end else if (load_dependency == `LoadDependent) begin
            issue_o = 1'b0;
            stallreq_from_id = `Stop;
        end else if (issue_en1 == 1'b1) begin
            issue_o = 1'b1;
            stallreq_from_id = `NoStop;
        end else begin
            issue_o = 1'b0;
            stallreq_from_id = `Stop;            
        end
    end
    
    // 指令1的设置
    always @ (*) begin
        if (is_in_delayslot_i & pre_inst_is_bly & ~ex_branch_flag) begin
            // branch-likely指令不跳转的话则不执行延迟槽指令
            aluop_o1 = `EXE_NOP_OP;
            alusel_o1 = `EXE_RES_NOP;
//            reg1_o1 = `ZeroWord;
//            reg2_o1 = `ZeroWord;
            wd_o1 = `NOPRegAddr;
            wreg_o1 = `WriteDisable;
            inst_addr_o1 = `ZeroWord;
            excepttype_o1 = `ZeroWord;
            imm_o1 = `ZeroWord;
            predict_pkt_o = 35'b0;
            cp0_sel_o = 3'b0;
            cp0_addr_o = 5'b0;
            is_bly1 = 1'b0;
        end else begin
            // 否则正常传输译码结果
            aluop_o1 = aluop_o1_temp;
            alusel_o1 = alusel_o1_temp;
//            reg1_o1 = reg1_o1_temp;
//            reg2_o1 = reg2_o1_temp;
            wd_o1 = wd_o1_temp;
            wreg_o1 = wreg_o1_temp;
            inst_addr_o1 = inst_addr_i1;
            excepttype_o1 = excepttype_o1_temp;
            imm_o1 = imm_temp;
            predict_pkt_o = predict_pkt;
            cp0_sel_o = cp0_sel_o_temp;
            cp0_addr_o = cp0_addr_o_temp;
            is_bly1 = is_bly1_temp;
        end
    end
    
    // 指令2的设置
    always @ (*) begin
        if (issue_mode == `SingleIssue) begin
            // 单发射则设置指令2为空指令
            aluop_o2 = `EXE_NOP_OP;
            alusel_o2 = `EXE_RES_NOP;
//            reg1_o2 = `ZeroWord;
//            reg2_o2 = `ZeroWord;
            wd_o2 = `NOPRegAddr;
            wreg_o2 = `WriteDisable;
            inst_addr_o2 = `ZeroWord;
            excepttype_o2 = `ZeroWord;
        end else begin
            // 双发射则将译码结果正常传输
            aluop_o2 = aluop_o2_temp;
            alusel_o2 = alusel_o2_temp;
//            reg1_o2 = reg1_o2_temp;
//            reg2_o2 = reg2_o2_temp;
            wd_o2 = wd_o2_temp;
            wreg_o2 = wreg_o2_temp;
            inst_addr_o2 = inst_addr_i2;
            excepttype_o2 = excepttype_o2_temp;
        end
    end
    
    // 延迟槽指令设置
    always @ (*) begin
        if (rst == `RstEnable) begin
            is_in_delayslot_o1 = `NotInDelaySlot;
            is_in_delayslot_o2 = `NotInDelaySlot;
        end else if (is_jb1 == 1'b1 && issue_mode == `DualIssue) begin
            // 如果指令1是转移指令且双发射，则指令2是延迟槽指令
            is_in_delayslot_o1 = is_in_delayslot_i;
            is_in_delayslot_o2 = `InDelaySlot;
        end else begin
            is_in_delayslot_o1 = is_in_delayslot_i;
            is_in_delayslot_o2 = `NotInDelaySlot;
        end
    end
    
endmodule
