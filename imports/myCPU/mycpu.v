`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/09 22:05:22
// Design Name: 
// Module Name: mycpu
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


module mycpu(
    input wire clk,
	input wire resetn,
	input wire [5:0] int,
	output wire timer_int_o,
	output wire flush,
	
	// connect with ICache
	input wire icache_valid_i1,  // 从icache取得的第一条指令是否有效
	input wire icache_valid_i2,
(*mark_debug = "true"*)	input wire [`RegBus] icache_addr_i1,  // 从icache返回来的第一条指令的地址
(*mark_debug = "true"*)	input wire [`RegBus] icache_addr_i2,  // 从icache返回来的第二条指令的地址
(*mark_debug = "true"*)	input wire [`RegBus] icache_data_i1,  // 从icache取得的第一条指令
(*mark_debug = "true"*)	input wire [`RegBus] icache_data_i2,  // 从icache取得的第二条指令
(*mark_debug = "true"*)    output wire [`RegBus] icache_addr_o1,  // 输出到icache的第一条指令的地址
(*mark_debug = "true"*)    output wire [`RegBus] icache_addr_o2,  // 输出到icache的第二条指令的地址
	output wire icache_req_o,
	output wire [2:0] icache_op,
	output wire [`RegBus] icache_cdata_o,
	
	// icache with branch_predict
	output wire ex_branch_flag,
	output wire predict_success,
	output wire [`InstAddrBus] ex_inst_addr_i1,
	output wire [`BPBPacketWidth] corr_pkt,
    output wire instbuffer_full,
    input wire [`BPBPacketWidth] icache_predict_pkt1,
    input wire [`BPBPacketWidth] icache_predict_pkt2,
    input wire [`InstAddrBus] icache_npc,
	
	// connect with DCache
    input wire stallreq_from_dcache,
(*mark_debug = "true"*)	input wire [`RegBus] dcache_data_i,
(*mark_debug = "true"*)	output wire [`RegBus] dcache_addr_o,
(*mark_debug = "true"*)	output wire [`RegBus] dcache_data_o,
	output wire dcache_wreq_o,
	output wire dcache_rreq_o,
	output wire [2:0] dcache_arsize_o,
	output wire [3:0] dcache_sel_o,
	output wire [2:0] dcache_op,
	
	// debug信息
	output wire [`RegBus] debug_wb_pc1,
	output wire [3:0] debug_wb_rf_wen1,
	output wire [`RegAddrBus] debug_wb_rf_wnum1,
	output wire [`RegBus] debug_wb_rf_wdata1,
	output wire [`RegBus] debug_wb_pc2,
    output wire [3:0] debug_wb_rf_wen2,
    output wire [`RegAddrBus] debug_wb_rf_wnum2,
    output wire [`RegBus] debug_wb_rf_wdata2,
    output wire [`RegBus] pref_addr_o
	
    );
    
    // PC模块的变量
    wire [`RegBus] epc_o;
    wire[`InstAddrBus] pc;
    
    // BPU模块的变量
    wire predict_flag;  //分支预测正确与否
    
    // 连接InstBuffer模块与ID模块的变量
    wire [`InstBus] issue_inst1;
    wire [`InstBus] issue_inst2;
    wire [`InstAddrBus] issue_inst_addr1;
    wire [`InstAddrBus] issue_inst_addr2;
    wire [`BPBPacketWidth] issue_predict_pkt;
    
    //连接译码阶段ID模块的输出与ID/EX模块的输入
    wire [`AluOpBus] id_aluop_o1;
    wire [`AluSelBus] id_alusel_o1;
    wire [`RegBus] id_reg1_o1;
    wire [`RegBus] id_reg2_o1;
    wire id_wreg_o1;
    wire [`RegAddrBus] id_wd_o1;
    wire [`InstAddrBus] id_inst_addr_o1;
    wire id_is_in_delayslot_o1;
    wire [31:0] id_excepttype_o1;
    
    wire [`AluOpBus] id_aluop_o2;
    wire [`AluSelBus] id_alusel_o2;
    wire [`RegBus] id_reg1_o2;
    wire [`RegBus] id_reg2_o2;
    wire id_wreg_o2;
    wire [`RegAddrBus] id_wd_o2;
    wire [`InstAddrBus] id_inst_addr_o2;
    wire id_is_in_delayslot_o2;
    wire [31:0] id_excepttype_o2;
    
    wire [`RegBus] id_imm_o1;
    wire [`RegBus] id_imm_o2;
    wire [`BPBPacketWidth] id_predict_pkt_o;
    wire [2:0] id_cp0_sel_o;
    wire [`RegAddrBus] id_cp0_addr_o;
    wire id_is_bly1_o;
//    wire is_jb1;
    
    //连接ID/EX模块的输出与执行阶段EX模块的输入
    wire [`AluOpBus] ex_aluop_i1;
    wire [`AluSelBus] ex_alusel_i1;
    wire [`RegBus] ex_reg1_i1;
    wire [`RegBus] ex_reg2_i1;
    wire ex_wreg_i1;
    wire [`RegAddrBus] ex_wd_i1;
    wire ex_is_in_delayslot_i1;
    wire [31:0] ex_excepttype_i1;
    
    wire [`AluOpBus] ex_aluop_i2;
    wire [`AluSelBus] ex_alusel_i2;
    wire [`RegBus] ex_reg1_i2;
    wire [`RegBus] ex_reg2_i2;
    wire ex_wreg_i2;
    wire [`RegAddrBus] ex_wd_i2;
    wire [`InstAddrBus] ex_inst_addr_i2;
    wire ex_is_in_delayslot_i2;
    wire [31:0] ex_excepttype_i2;
    
    wire [`RegBus] ex_imm_i1;
    wire [`BPBPacketWidth] ex_predict_pkt_i;
    wire [2:0] ex_cp0_sel_i;
    wire [`RegAddrBus] ex_cp0_addr_i;
    wire ex_is_bly1_i;
    
    //连接执行阶段EX模块的输出与EX/MEM模块的输入
    wire ex_wreg_o1;
    wire [`RegAddrBus] ex_wd_o1;
    wire [`RegBus] ex_wdata_o1;
    wire [31:0] ex_excepttype_o1;
    wire ex_is_in_delayslot_o1;
(*mark_debug = "true"*)    wire [`InstAddrBus] ex_inst_addr_o1;

    wire ex_wreg_o2;
    wire [`RegAddrBus] ex_wd_o2;
    wire [`RegBus] ex_wdata_o2;
    wire [31:0] ex_excepttype_o2;
    wire ex_is_in_delayslot_o2;
    wire [`InstAddrBus] ex_inst_addr_o2;
    
    wire ex_LLbit_o;
    wire ex_LLbit_we_o;
    
    // 乘累加、乘累减有关的变量
    wire [`DoubleRegBus] hilo_temp_i;
    wire [1:0] cnt_i;
    wire [`DoubleRegBus] hilo_temp_o;
    wire [1:0] cnt_o;
    
    // 访存指令有关的变量
    wire [`AluOpBus] ex_aluop_o1;
    wire [`RegBus] ex_mem_addr;
    wire [`RegBus] ex_reg2_o1;
    
    // 特权指令有关的变量
    wire ex_cp0_we_o;
    wire [2:0] ex_cp0_wsel_o;
    wire [`RegAddrBus] ex_cp0_waddr_o;
    wire [`RegBus] ex_cp0_wdata_o;
    
    // CACHE指令有关的变量
    wire icache_creq_o;
    wire [`RegBus] icache_caddr_o;
    
    // 连接EX/MEM模块的输出与访存阶段MEM模块的输入
    wire mem_wreg_i1;
    wire [`RegAddrBus] mem_wd_i1;
    wire [`RegBus] mem_wdata_i1;
    wire [`InstAddrBus] mem_inst_addr_i1;
    wire [31:0] mem_excepttype_i1;
    wire mem_is_in_delayslot_i1;
    
    wire mem_wreg_i2;
    wire [`RegAddrBus] mem_wd_i2;
    wire [`RegBus] mem_wdata_i2;
    wire [`InstAddrBus] mem_inst_addr_i2;
    wire [31:0] mem_excepttype_i2;
    wire mem_is_in_delayslot_i2;

    wire mem_LLbit_i;
    wire mem_LLbit_we_i;
    
    // 访存指令有关的变量
    wire [`AluOpBus] mem_aluop_i1;
    wire [`RegBus] mem_mem_addr;
    wire [`RegBus] mem_reg2_i1;
    
    // 特权指令有关的信息
    wire mem_cp0_we_i;
    wire [2:0] mem_cp0_wsel_i;
    wire [4:0] mem_cp0_waddr_i;
    wire [`RegBus] mem_cp0_wdata_i;
    
    //连接访存阶段MEM模块的输出与COMMIT模块的输入
    wire mem_wreg_o1;
    wire [`RegAddrBus] mem_wd_o1;
    wire [`RegBus] mem_wdata_o1;
    
    wire mem_wreg_o2;
    wire [`RegAddrBus] mem_wd_o2;
    wire [`RegBus] mem_wdata_o2;
    
    wire mem_LLbit_o;
    wire mem_LLbit_we_o;
    
    // 特权指令有关的信息
    wire mem_cp0_we_o;
    wire [2:0] mem_cp0_wsel_o;
    wire [4:0] mem_cp0_waddr_o;
    wire [`RegBus] mem_cp0_wdata_o;
    
    // 异常相关的信息
    wire [`RegBus] mem_inst_addr_o1;
    wire mem_is_in_delayslot_o1;
    wire [`RegBus] mem_inst_addr_o2;
    wire mem_is_in_delayslot_o2;
    wire [4:0] excepttype_o;
    wire exception_flag;
    wire exception_inst_sel;
    wire [`RegBus] mem_cp0_epc;
    wire [`RegBus] mem_cp0_ebase;
    wire [`RegBus] cp0_mem_addr;
    
    //连接COMMIT模块的输出与寄存器堆的输入    
    wire we_o1;
    wire[`RegAddrBus] waddr_o1;
    wire[`RegBus] wdata_o1;
    
    wire we_o2;
    wire[`RegAddrBus] waddr_o2;
    wire[`RegBus] wdata_o2;
        
    //连接译码阶段ID模块与通用寄存器Regfile模块
    wire reg1_read1;
    wire reg2_read1;
    wire[`RegBus] reg1_data1;
    wire[`RegBus] reg2_data1;
    wire[`RegAddrBus] reg1_addr1;
    wire[`RegAddrBus] reg2_addr1;
    
    wire reg1_read2;
    wire reg2_read2;
    wire[`RegBus] reg1_data2;
    wire[`RegBus] reg2_data2;
    wire[`RegAddrBus] reg1_addr2;
    wire[`RegAddrBus] reg2_addr2;
    
    // 连接cp0_reg模块的信息
    wire cp0_we_i;
    wire [4:0] cp0_waddr_i;
    wire [4:0] cp0_raddr_i;
    wire [2:0] cp0_rsel_i;
    wire [2:0] cp0_wsel_i;
    wire [`RegBus] cp0_data_i;
    wire [`RegBus] cp0_data_o;
    
    wire [`RegBus] cp0_index;
    wire [`RegBus] cp0_random;
    wire [`RegBus] cp0_entrylo0;
    wire [`RegBus] cp0_entrylo1;
    wire [`RegBus] cp0_entryhi;
    wire [`RegBus] cp0_context;
    wire [`RegBus] cp0_pagemask;
    wire [`RegBus] cp0_wired;
    wire [`RegBus] cp0_badvaddr;
    wire [`RegBus] cp0_count;
    wire [`RegBus] cp0_compare;
    wire [`RegBus] cp0_status;
    wire [`RegBus] cp0_cause;
    wire [`RegBus] cp0_epc;
    wire [`RegBus] cp0_config;
    wire [`RegBus] cp0_config1;
    wire [`RegBus] cp0_ebase;
    wire [`RegBus] cp0_prid;
    wire [`RegBus] cp0_taglo;
    wire [`RegBus] cp0_taghi;
    
    // 连接HILO模块的信息
    wire [`RegBus] hi_i;
    wire [`RegBus] lo_i;
    wire whilo_i;
    wire [`RegBus] hi_o;
    wire [`RegBus] lo_o;
    
    // 连接LLbit模块的信息
    wire LLbit_i;
    wire LLbit_we;
    wire LLbit_o;
    
    // 连接DIV模块的信息
    wire signed_div;
    wire[`RegBus] div_opdata1;
    wire[`RegBus] div_opdata2;
    wire div_start;
    wire[`DoubleRegBus] div_result;
    wire div_ready;
    
    // 转移指令设置
    wire is_in_delayslot_i;
    wire next_inst_in_delayslot;
    wire [`RegBus] ex_branch_target_addr;
    
    // 指令发射模式设置
    wire issue_mode;
    wire issue_o;
    wire issue_en1;
    wire issue_en2;
    
    // 流水线暂停及清空设置
    wire stallreq_from_id;
    wire stallreq_from_ex;
//    wire stallreq_from_delayslot;
    wire [3:0] stall;
    wire flush_cause;
    
    wire icache_rreq_o;
	
	// TLB指令相关的变量
	wire             cp0_entryhi_we;
    wire [`RegBus]   cp0_entryhi_i; 
    wire             cp0_entrylo0_we;
    wire [`RegBus]   cp0_entrylo0_i; 
    wire             cp0_entrylo1_we;
    wire [`RegBus]   cp0_entrylo1_i;    

    assign icache_addr_o1 = &icache_op ? pc : icache_caddr_o;  // icache的第一条指令的地址就是pc的值
    assign icache_addr_o2 = pc + 32'h4;  // icache的第二条指令的地址就是pc+4的值
    assign icache_req_o = icache_rreq_o | icache_creq_o;
    
    assign debug_wb_rf_wnum1 = waddr_o1;
    assign debug_wb_rf_wen1 = {4{we_o1}};
    assign debug_wb_rf_wdata1 = wdata_o1;
    assign debug_wb_rf_wnum2 = waddr_o2;
    assign debug_wb_rf_wen2 = {4{we_o2}};
    assign debug_wb_rf_wdata2 = wdata_o2;
    
      
    //pc_reg例化
    pc_reg pc_reg0(
        .clk(clk),
        .resetn(resetn),
        .flush(flush),
        .flush_cause(flush_cause),
        .epc(epc_o),
        .instbuffer_full(instbuffer_full),
        .icache_npc(icache_npc),
        
        .branch_flag_i(ex_branch_flag),
        .branch_target_address_i(ex_branch_target_addr),
        .ex_inst_addr(ex_inst_addr_i1),
        
        .pc(pc),
        .icache_rreq_o(icache_rreq_o)                
    );
    
    instbuffer instbuffer0(
        .clk(clk),
        .rst(resetn),
        .flush(flush),
        .issue_mode(issue_mode),
        .issue_i(issue_o),
//        .is_jb1(is_jb1),
//        .stallreq_from_icache(stallreq_from_icache),
//        .stallreq_from_delayslot(stallreq_from_delayslot),
        .issue_en1(issue_en1),
//        .issue_en2(issue_en2),
        .instbuffer_full(instbuffer_full),
        .inst_i1(icache_data_i1),
        .inst_i2(icache_data_i2),
        .inst_addr_i1(icache_addr_i1),
        .inst_addr_i2(icache_addr_i2),
        .inst_valid1(icache_valid_i1),
        .inst_valid2(icache_valid_i2),
        .predict_pkt1(icache_predict_pkt1),
        .predict_pkt2(icache_predict_pkt2),
        .issue_inst1(issue_inst1),
        .issue_inst2(issue_inst2),
        .issue_inst_addr1(issue_inst_addr1),
        .issue_inst_addr2(issue_inst_addr2),
        .issue_predict_pkt(issue_predict_pkt)

    );
    
    //译码阶段ID模块
    id id0(
        .clk(clk),
        .rst(resetn),
        .stallreq_from_ex(stallreq_from_ex),
        .stallreq_from_dcache(stallreq_from_dcache),        
        .predict_pkt(issue_predict_pkt),
        .pre_inst_is_bly(ex_is_bly1_i),
        .ex_branch_flag(ex_branch_flag),
        
        .inst_addr_i1(issue_inst_addr1),
        .inst_addr_i2(issue_inst_addr2),
        .inst_i1(issue_inst1),
        .inst_i2(issue_inst2),
        
//        .reg1_data_i1(reg1_data1),
//        .reg2_data_i1(reg2_data1),
//        .reg1_data_i2(reg1_data2),
//        .reg2_data_i2(reg2_data2),

        //送到regfile的信息
        .reg1_read_o1(reg1_read1),
        .reg2_read_o1(reg2_read1),       
        .reg1_addr_o1(reg1_addr1),
        .reg2_addr_o1(reg2_addr1), 
        
        .reg1_read_o2(reg1_read2),
        .reg2_read_o2(reg2_read2),       
        .reg1_addr_o2(reg1_addr2),
        .reg2_addr_o2(reg2_addr2), 
        
        //送到ID/EX模块的信息
        .imm_o1(id_imm_o1),
        .aluop_o1(id_aluop_o1),
        .alusel_o1(id_alusel_o1),
//        .reg1_o1(id_reg1_o1),
//        .reg2_o1(id_reg2_o1),
        .wd_o1(id_wd_o1),
        .wreg_o1(id_wreg_o1),
        .inst_addr_o1(id_inst_addr_o1),
        .is_in_delayslot_o1(id_is_in_delayslot_o1),
        .excepttype_o1(id_excepttype_o1),
        
        .imm_o2(id_imm_o2),
        .aluop_o2(id_aluop_o2),
        .alusel_o2(id_alusel_o2),
//        .reg1_o2(id_reg1_o2),
//        .reg2_o2(id_reg2_o2),
        .wd_o2(id_wd_o2),
        .wreg_o2(id_wreg_o2),
        .inst_addr_o2(id_inst_addr_o2),
        .is_in_delayslot_o2(id_is_in_delayslot_o2),
        .excepttype_o2(id_excepttype_o2),
        
        .predict_pkt_o(id_predict_pkt_o),
        .cp0_sel_o(id_cp0_sel_o),
        .cp0_addr_o(id_cp0_addr_o),
        .is_bly1(id_is_bly1_o),
        
        // 解决数据相关问题
        .ex_waddr_i1(ex_wd_o1),
        .ex_waddr_i2(ex_wd_o2),
//        .ex_we_i1(ex_wreg_o1),
//        .ex_we_i2(ex_wreg_o2),
//        .ex_wdata_i1(ex_wdata_o1),
//        .ex_wdata_i2(ex_wdata_o2),
//        .mem_waddr_i1(mem_wd_o1),
//        .mem_waddr_i2(mem_wd_o2),
//        .mem_we_i1(mem_wreg_o1),
//        .mem_we_i2(mem_wreg_o2),
//        .mem_wdata_i1(mem_wdata_o1),
//        .mem_wdata_i2(mem_wdata_o2),
        .ex_aluop_i1(ex_aluop_o1),
        
        // 转移指令设置
        .is_in_delayslot_i(is_in_delayslot_i),
        .next_inst_in_delayslot(next_inst_in_delayslot),
        
        // 发射条数设置
        .issue_mode(issue_mode),
        .issue_o(issue_o),
        .issue_en1(issue_en1),
        
        .stallreq_from_id(stallreq_from_id)
    );

  //通用寄存器Regfile例化
    regfile regfile1(
        .clk (clk),
        .rst (resetn),
        .we1    (we_o1),
        .waddr1 (waddr_o1),
        .wdata1 (wdata_o1),
        .we2    (we_o2),
        .waddr2 (waddr_o2),
        .wdata2 (wdata_o2),
        
        .re1 (reg1_read1),
        .raddr1 (reg1_addr1),
        .rdata1 (reg1_data1),
        .re2 (reg2_read1),
        .raddr2 (reg2_addr1),
        .rdata2 (reg2_data1),
        .re3 (reg1_read2),
        .raddr3 (reg1_addr2),
        .rdata3 (reg1_data2),
        .re4 (reg2_read2),
        .raddr4 (reg2_addr2),
        .rdata4 (reg2_data2)
    );
    
    forward_sub1 u_forward_sub1(
        .clk(clk),
        .rst(resetn),
        .flush(flush),
        .flush_cause(flush_cause),
        .stall(stall),
        .is_in_delayslot(is_in_delayslot_i),
        
        .re1(reg1_read1),
        .raddr1(reg1_addr1),
        .rdata1(reg1_data1),
        .re2(reg2_read1),
        .raddr2(reg2_addr1),
        .rdata2(reg2_data1),
        
        .imm(id_imm_o1),
        .ex_waddr_i1(ex_wd_o1),
        .ex_waddr_i2(ex_wd_o2),
        .ex_we_i1(ex_wreg_o1),
        .ex_we_i2(ex_wreg_o2),
        .ex_wdata_i1(ex_wdata_o1),
        .ex_wdata_i2(ex_wdata_o2),
        .mem_waddr_i1(mem_wd_o1),
        .mem_waddr_i2(mem_wd_o2),
        .mem_we_i1(mem_wreg_o1),
        .mem_we_i2(mem_wreg_o2),
        .mem_wdata_i1(mem_wdata_o1),
        .mem_wdata_i2(mem_wdata_o2),
        
        .reg1_o(ex_reg1_i1),
        .reg2_o(ex_reg2_i1)
    );
    
    forward_sub2 u_forward_sub2(
        .clk(clk),
        .rst(resetn),
        .flush(flush),
        .stall(stall),
        .issue_mode(issue_mode),
        
        .re1(reg1_read2),
        .raddr1(reg1_addr2),
        .rdata1(reg1_data2),
        .re2(reg2_read2),
        .raddr2(reg2_addr2),
        .rdata2(reg2_data2),
        
        .imm(id_imm_o2),
        .ex_waddr_i1(ex_wd_o1),
        .ex_waddr_i2(ex_wd_o2),
        .ex_we_i1(ex_wreg_o1),
        .ex_we_i2(ex_wreg_o2),
        .ex_wdata_i1(ex_wdata_o1),
        .ex_wdata_i2(ex_wdata_o2),
        .mem_waddr_i1(mem_wd_o1),
        .mem_waddr_i2(mem_wd_o2),
        .mem_we_i1(mem_wreg_o1),
        .mem_we_i2(mem_wreg_o2),
        .mem_wdata_i1(mem_wdata_o1),
        .mem_wdata_i2(mem_wdata_o2),
        
        .reg1_o(ex_reg1_i2),
        .reg2_o(ex_reg2_i2)
    );

    //ID/EX模块
    id_ex id_ex0(
        .clk(clk),
        .rst(resetn),
        .stall(stall),
        .flush(flush),
        .flush_cause(flush_cause),
        
        //从译码阶段ID模块传递的信息
        .id_aluop1(id_aluop_o1),
        .id_alusel1(id_alusel_o1),
//        .id_reg1(id_reg1_o1),
//        .id_reg2(id_reg2_o1),
        .id_wd1(id_wd_o1),
        .id_wreg1(id_wreg_o1),
        .id_inst_addr1(id_inst_addr_o1),
        .id_is_in_delayslot1(id_is_in_delayslot_o1),
        .id_excepttype1(id_excepttype_o1),
        
        .id_aluop2(id_aluop_o2),
        .id_alusel2(id_alusel_o2),
//        .id_reg3(id_reg1_o2),
//        .id_reg4(id_reg2_o2),
        .id_wd2(id_wd_o2),
        .id_wreg2(id_wreg_o2),
        .id_inst_addr2(id_inst_addr_o2),
        .id_is_in_delayslot2(id_is_in_delayslot_o2),
        .id_excepttype2(id_excepttype_o2),
        
        .id_imm(id_imm_o1),
        .id_predict_pkt(id_predict_pkt_o),
        .next_inst_in_delayslot(next_inst_in_delayslot),
        .id_cp0_sel(id_cp0_sel_o),
        .id_cp0_addr(id_cp0_addr_o),
        .id_is_bly1(id_is_bly1_o),
        
        //传递到执行阶段EX模块的信息
        .ex_aluop1(ex_aluop_i1),
        .ex_alusel1(ex_alusel_i1),
//        .ex_reg1(ex_reg1_i1),
//        .ex_reg2(ex_reg2_i1),
        .ex_wd1(ex_wd_i1),
        .ex_wreg1(ex_wreg_i1),
        .ex_inst_addr1(ex_inst_addr_i1),
        .ex_is_in_delayslot1(ex_is_in_delayslot_i1),
        .ex_excepttype1(ex_excepttype_i1),
        
        .ex_aluop2(ex_aluop_i2),
        .ex_alusel2(ex_alusel_i2),
//        .ex_reg3(ex_reg1_i2),
//        .ex_reg4(ex_reg2_i2),
        .ex_wd2(ex_wd_i2),
        .ex_wreg2(ex_wreg_i2),
        .ex_inst_addr2(ex_inst_addr_i2),
        .ex_is_in_delayslot2(ex_is_in_delayslot_i2),
        .ex_excepttype2(ex_excepttype_i2),
        
        .ex_imm(ex_imm_i1),
        .ex_predict_pkt(ex_predict_pkt_i),
        .is_in_delayslot_o(is_in_delayslot_i),
        .ex_cp0_sel(ex_cp0_sel_i),
        .ex_cp0_addr(ex_cp0_addr_i),
        .ex_is_bly1(ex_is_bly1_i)
    );        
    
    //EX模块
    ex ex0(
        .rst(resetn),
    
        //送到执行阶段EX模块的信息
        .aluop_i1(ex_aluop_i1),
        .alusel_i1(ex_alusel_i1),
        .reg1_i1(ex_reg1_i1),
        .reg2_i1(ex_reg2_i1),
        .wd_i1(ex_wd_i1),
        .wreg_i1(ex_wreg_i1),
        .inst_addr_i1(ex_inst_addr_i1),
        .is_in_delayslot_i1(ex_is_in_delayslot_i1),
        .excepttype_i1(ex_excepttype_i1),
        
        .aluop_i2(ex_aluop_i2),
        .alusel_i2(ex_alusel_i2),
        .reg1_i2(ex_reg1_i2),
        .reg2_i2(ex_reg2_i2),
        .wd_i2(ex_wd_i2),
        .wreg_i2(ex_wreg_i2),
        .inst_addr_i2(ex_inst_addr_i2),
        .is_in_delayslot_i2(ex_is_in_delayslot_i2),
        .excepttype_i2(ex_excepttype_i2),
        
        .hi_i(hi_o),
        .lo_i(lo_o),
        .imm_i(ex_imm_i1),
        .predict_pkt_i(ex_predict_pkt_i),
        .mem_exception_flag(exception_flag),
        .is_bly1(ex_is_bly1_i),
        
        // 解决数据相关问题
        // LLbit
        .LLbit_i(LLbit_o),
        .mem_LLbit_i(mem_LLbit_o),
        .mem_LLbit_we_i(mem_LLbit_we_o),
        .commit_LLbit_i(LLbit_i),
        .commit_LLbit_we_i(LLbit_we),
        // cp0
        .cp0_sel_i(ex_cp0_sel_i),
        .cp0_addr_i(ex_cp0_addr_i),
        .cp0_data_i(cp0_data_o),
        .mem_cp0_wsel_i(mem_cp0_wsel_o),
        .mem_cp0_we_i(mem_cp0_we_o),
        .mem_cp0_waddr_i(mem_cp0_waddr_o),
        .commit_cp0_wsel_i(cp0_wsel_i),
        .commit_cp0_we_i(cp0_we_i),
        .commit_cp0_waddr_i(cp0_waddr_i),
        
        //EX模块的输出到EX/MEM模块信息
        .wd_o1(ex_wd_o1),
        .wreg_o1(ex_wreg_o1),
        .wdata_o1(ex_wdata_o1),
        .inst_addr_o1(ex_inst_addr_o1),
        .is_in_delayslot_o1(ex_is_in_delayslot_o1),
        .excepttype_o1(ex_excepttype_o1),
        
        .wd_o2(ex_wd_o2),
        .wreg_o2(ex_wreg_o2),
        .wdata_o2(ex_wdata_o2),
        .inst_addr_o2(ex_inst_addr_o2),
        .is_in_delayslot_o2(ex_is_in_delayslot_o2),
        .excepttype_o2(ex_excepttype_o2),
        
        .hi_o(hi_i),
        .lo_o(lo_i),
        .whilo_o(whilo_i),
        .LLbit_o(ex_LLbit_o),
        .LLbit_we_o(ex_LLbit_we_o),
        
        // 乘累加、乘累减有关的变量
        .hilo_temp_i(hilo_temp_i),
        .cnt_i(cnt_i),
        .hilo_temp_o(hilo_temp_o),
        .cnt_o(cnt_o),
        
        // 与除法模块有关的变量
        .div_result_i(div_result),
        .div_ready_i(div_ready),
        .div_opdata1_o(div_opdata1),
        .div_opdata2_o(div_opdata2),
        .div_start_o(div_start),
        .signed_div_o(signed_div),
        
        // CACHE指令有关的变量
        .icache_op(icache_op),
        .icache_creq(icache_creq_o),
        .icache_caddr_o(icache_caddr_o),
        .icache_cdata_o(icache_cdata_o),
        .dcache_op(dcache_op),
        
        // 转移指令有关的变量
        .ex_branch_flag(ex_branch_flag),
        .ex_branch_target_addr(ex_branch_target_addr),
        .predict_flag(predict_flag),
        .corr_pkt(corr_pkt),
        .predict_success(predict_success),
        
        // 访存指令有关的变量
        .aluop_o1(ex_aluop_o1),
        .reg2_o1(ex_reg2_o1),
        .mem_addr_o(ex_mem_addr),
        .dcache_addr_o(dcache_addr_o),
        .mem_we_o(dcache_wreq_o),
        .mem_sel_o(dcache_sel_o),
        .mem_arsize_o(dcache_arsize_o),
        .mem_data_o(dcache_data_o),
        .mem_re_o(dcache_rreq_o),
        
        // 特权指令有关的变量
        .cp0_we_o(ex_cp0_we_o),
        .cp0_wsel_o(ex_cp0_wsel_o),
        .cp0_rsel_o(cp0_rsel_i),
        .cp0_waddr_o(ex_cp0_waddr_o),
        .cp0_wdata_o(ex_cp0_wdata_o),
        .cp0_raddr_o(cp0_raddr_i),
        
        .stallreq_from_ex(stallreq_from_ex)
        
    );

  //EX/MEM模块
  ex_mem ex_mem0(
        .clk(clk),
        .rst(resetn),
        .flush(flush),
        .flush_cause(flush_cause),
        .stall(stall),
      
        //来自执行阶段EX模块的信息    
        .ex_wd1(ex_wd_o1),
        .ex_wreg1(ex_wreg_o1),
        .ex_wdata1(ex_wdata_o1),
        .ex_inst_addr1(ex_inst_addr_o1),
        .ex_excepttype1(ex_excepttype_o1),
        .ex_is_in_delayslot1(ex_is_in_delayslot_o1),
        
        .ex_wd2(ex_wd_o2),
        .ex_wreg2(ex_wreg_o2),
        .ex_wdata2(ex_wdata_o2),
        .ex_inst_addr2(ex_inst_addr_o2),
        .ex_excepttype2(ex_excepttype_o2),
        .ex_is_in_delayslot2(ex_is_in_delayslot_o2),

        .ex_LLbit(ex_LLbit_o),
        .ex_LLbit_we(ex_LLbit_we_o),
        
        .ex_aluop1(ex_aluop_o1),
        .ex_mem_addr(ex_mem_addr),
        .ex_reg2(ex_reg2_o1),
        
        .ex_cp0_we(ex_cp0_we_o),
        .ex_cp0_wsel(ex_cp0_wsel_o),
        .ex_cp0_waddr(ex_cp0_waddr_o),
        .ex_cp0_wdata(ex_cp0_wdata_o),
        
        // 乘累加、乘累减有关的变量
        .hilo_i(hilo_temp_o),
        .cnt_i(cnt_o),
        .hilo_o(hilo_temp_i),
        .cnt_o(cnt_i),
        
        //送到访存阶段MEM模块的信息
        .mem_wd1(mem_wd_i1),
        .mem_wreg1(mem_wreg_i1),
        .mem_wdata1(mem_wdata_i1),
        .mem_inst_addr1(mem_inst_addr_i1),
        .mem_excepttype1(mem_excepttype_i1),
        .mem_is_in_delayslot1(mem_is_in_delayslot_i1),
        
        .mem_wd2(mem_wd_i2),
        .mem_wreg2(mem_wreg_i2),
        .mem_wdata2(mem_wdata_i2),
        .mem_inst_addr2(mem_inst_addr_i2),
        .mem_excepttype2(mem_excepttype_i2),
        .mem_is_in_delayslot2(mem_is_in_delayslot_i2),
        
        .mem_LLbit(mem_LLbit_i),
        .mem_LLbit_we(mem_LLbit_we_i),
        
        .mem_aluop1(mem_aluop_i1),
        .mem_mem_addr(mem_mem_addr),
        .mem_reg2(mem_reg2_i1),
        
        .mem_cp0_we(mem_cp0_we_i),
        .mem_cp0_wsel(mem_cp0_wsel_i),
        .mem_cp0_waddr(mem_cp0_waddr_i),
        .mem_cp0_wdata(mem_cp0_wdata_i)
                                
    );
    
  //MEM模块例化
    mem mem0(
        .rst(resetn),
    
        //来自EX/MEM模块的信息    
        .wd_i1(mem_wd_i1),
        .wreg_i1(mem_wreg_i1),
        .wdata_i1(mem_wdata_i1),
        .inst_addr_i1(mem_inst_addr_i1),
        .is_in_delayslot_i1(mem_is_in_delayslot_i1),
        .excepttype_i1(mem_excepttype_i1),
        
        .wd_i2(mem_wd_i2),
        .wreg_i2(mem_wreg_i2),
        .wdata_i2(mem_wdata_i2),
        .inst_addr_i2(mem_inst_addr_i2),
        .is_in_delayslot_i2(mem_is_in_delayslot_i2),
        .excepttype_i2(mem_excepttype_i2),
      
        .LLbit_i(mem_LLbit_i),
        .LLbit_we_i(mem_LLbit_we_i),
        
        .aluop_i(mem_aluop_i1),
        .mem_addr_i(mem_mem_addr),
        .reg2_i(mem_reg2_i1),
        .mem_data_i(dcache_data_i),
        
        .cp0_we_i(mem_cp0_we_i),
        .cp0_wsel_i(mem_cp0_wsel_i),
        .cp0_waddr_i(mem_cp0_waddr_i),
        .cp0_wdata_i(mem_cp0_wdata_i),
        
        // 异常有关的信息
        .cp0_status_i(cp0_status),
        .cp0_cause_i(cp0_cause),
        .cp0_epc_i(cp0_epc),
        .cp0_ebase_i(cp0_ebase),
        .commit_cp0_we_i(cp0_we_i),
        .commit_cp0_wsel_i(cp0_wsel_i),
        .commit_cp0_waddr_i(cp0_waddr_i),
        .commit_cp0_wdata_i(cp0_data_i),
        
        //送到COMMIT模块的信息
        .wd_o1(mem_wd_o1),
        .wreg_o1(mem_wreg_o1),
        .wdata_o1(mem_wdata_o1),       
        
        .wd_o2(mem_wd_o2),
        .wreg_o2(mem_wreg_o2),
        .wdata_o2(mem_wdata_o2),
        
        .LLbit_o(mem_LLbit_o),
        .LLbit_we_o(mem_LLbit_we_o),
        
        .cp0_we_o(mem_cp0_we_o),
        .cp0_wsel_o(mem_cp0_wsel_o),
        .cp0_waddr_o(mem_cp0_waddr_o),
        .cp0_wdata_o(mem_cp0_wdata_o),
        
        // 异常相关的信息
        .inst_addr_o1(mem_inst_addr_o1),
        .is_in_delayslot_o1(mem_is_in_delayslot_o1),
        .inst_addr_o2(mem_inst_addr_o2),
        .is_in_delayslot_o2(mem_is_in_delayslot_o2),
        .excepttype_o(excepttype_o),
        .exception_flag(exception_flag),
        .exception_inst_sel(exception_inst_sel),
        .cp0_epc_o(mem_cp0_epc),
        .cp0_ebase_o(mem_cp0_ebase),
        .mem_addr_o(cp0_mem_addr)
        
    );

  //COMMIT模块
    commit commit0(
        .clk(clk),
        .rst(resetn),
        .stall(stall),
        .flush(flush),
        .flush_cause(flush_cause),
        .exception_inst_sel(exception_inst_sel),

        //来自访存阶段MEM模块的信息    
        .waddr_i1(mem_wd_o1),
        .we_i1(mem_wreg_o1),
        .wdata_i1(mem_wdata_o1),
        .inst_addr_i1(mem_inst_addr_o1),

        .waddr_i2(mem_wd_o2),
        .we_i2(mem_wreg_o2),
        .wdata_i2(mem_wdata_o2),
        .inst_addr_i2(mem_inst_addr_o2),
        
        .LLbit_i(mem_LLbit_o),
        .LLbit_we_i(mem_LLbit_we_o),
        
        .cp0_we_i(mem_cp0_we_o),
        .cp0_wsel_i(mem_cp0_wsel_o),
        .cp0_waddr_i(mem_cp0_waddr_o),
        .cp0_wdata_i(mem_cp0_wdata_o),
        
        //送到寄存器堆的信息
        .waddr_o1(waddr_o1),
        .we_o1(we_o1),
        .wdata_o1(wdata_o1),
        .inst_addr_o1(debug_wb_pc1),
        
        .waddr_o2(waddr_o2),
        .we_o2(we_o2),
        .wdata_o2(wdata_o2),
        .inst_addr_o2(debug_wb_pc2),
        
        .LLbit_o(LLbit_i),
        .LLbit_we_o(LLbit_we),
        
        .cp0_we_o(cp0_we_i),
        .cp0_wsel_o(cp0_wsel_i),
        .cp0_waddr_o(cp0_waddr_i),
        .cp0_wdata_o(cp0_data_i),
        
        .pref_addr_i(cp0_mem_addr),
        .pref_addr_o(pref_addr_o)
                                                
    );
    
    div div0(
        .clk(clk),
        .rst(resetn),
        .signed_div_i(signed_div),
        .opdata1_i(div_opdata1),
        .opdata2_i(div_opdata2),
        .start_i(div_start),
        .annul_i(1'b0),
        .result_o(div_result),
        .ready_o(div_ready)
    );
    
    hilo_reg hilo_reg0(
        .clk(clk),
        .rst(resetn),
        .we(whilo_i),
        .hi_i(hi_i),
        .lo_i(lo_i),
        .hi_o(hi_o),
        .lo_o(lo_o)
    );
    
    LLbit_reg LLbit_reg0(
        .clk(clk),
        .rst(resetn),
        .flush(flush),
        .flush_cause(flush_cause),
        .LLbit_i(LLbit_i),
        .we(LLbit_we),
        .LLbit_o(LLbit_o)
    );
    
    ctrl ctrl0(
        .rst(resetn),
        .predict_flag(predict_flag),
        .stallreq_from_id(stallreq_from_id),
        .stallreq_from_ex(stallreq_from_ex),
        .stallreq_from_dcache(stallreq_from_dcache),
//        .stallreq_from_delayslot(stallreq_from_delayslot),
        .stall(stall),
        .flush(flush),
        .flush_cause(flush_cause),
        
        // 异常相关的信息
        .exception_flag(exception_flag),
        .excepttype_i(excepttype_o),
        .cp0_epc_i(mem_cp0_epc), 
        .cp0_ebase_i(mem_cp0_ebase), 
        .epc_o(epc_o)         
    );
        
    cp0_reg cp0_reg0(
        .clk(clk),
        .rst(resetn),
        .int_i(int),
    
        .we_i(cp0_we_i),
        .rsel_i(cp0_rsel_i),
        .wsel_i(cp0_wsel_i),
        .waddr_i(cp0_waddr_i),
        .raddr_i(cp0_raddr_i),
        .data_i(cp0_data_i),
        .data_o(cp0_data_o),
        
        .cp0_entryhi_we(cp0_entryhi_we), 
        .cp0_entryhi_i (cp0_entryhi_i),  
        .cp0_entrylo0_we(cp0_entrylo0_we),
        .cp0_entrylo0_i(cp0_entrylo0_i), 
        .cp0_entrylo1_we(cp0_entrylo1_we),
        .cp0_entrylo1_i(cp0_entrylo1_i),
         
        // 异常相关的信息
        .exception_flag(exception_flag),
        .excepttype_i(excepttype_o),
        .exception_inst_sel(exception_inst_sel),
        .inst_addr_i1(mem_inst_addr_o1),
        .inst_addr_i2(mem_inst_addr_o2),
        .mem_addr_i(cp0_mem_addr),
        .is_in_delayslot_i1(mem_is_in_delayslot_o1),
        .is_in_delayslot_i2(mem_is_in_delayslot_o2),
        
        .index_o(cp0_index),
        .random_o(cp0_random),
        .entrylo0_o(cp0_entrylo0),
        .entrylo1_o(cp0_entrylo1),
        .entryhi_o(cp0_entryhi),
        .context_o(cp0_context),
        .pagemask_o(cp0_pagemask),
        .wired_o(cp0_wired),
        .badvaddr_o(cp0_badvaddr),
        .count_o(cp0_count),
        .compare_o(cp0_compare),
        .status_o(cp0_status),
        .cause_o(cp0_cause),
        .epc_o(cp0_epc),
        .config_o(cp0_config),
        .config1_o(cp0_config1),
        .ebase_o(cp0_ebase),
        .prid_o(cp0_prid),
        .taglo_o(cp0_taglo),
        .taghi_o(cp0_taghi),
        .timer_int_o(timer_int_o)
    );
    
    wire [31:0] jb_cnt;
    wire [31:0] wrong_cnt;
    wire [31:0] j_cnt;
    wire [31:0] b_cnt;
    wire [31:0] r_cnt;
    
    bpu_test u_bpu_test(
        .clk(clk),
        .resetn(resetn),
        
        .aluop_i(ex_aluop_i1),
        .stallreq_from_ex(stallreq_from_ex),
        .stallreq_from_dcache(stallreq_from_dcache),
        .predict_flag(predict_flag),
        .wrong_type(corr_pkt[1:0]),
        
        .jb_cnt(jb_cnt),
        .wrong_cnt(wrong_cnt),
        .j_cnt(j_cnt),
        .b_cnt(b_cnt),
        .r_cnt(r_cnt)
   );    
    
    
endmodule
