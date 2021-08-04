`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/26 22:17:54
// Design Name: 
// Module Name: cp0_reg
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


module cp0_reg(

    input wire clk,
	input wire rst,
	
	input wire we_i,
	input wire [4:0] waddr_i,  // 要写的CP0中寄存器的地址
	input wire [4:0] raddr_i,  // 要读取的CP0中寄存器的地址
	input wire [2:0] rsel_i,
	input wire [2:0] wsel_i,
	input wire [`RegBus] data_i,
	
	input wire [5:0] int_i,  // 6个外部硬件中断输入
	
	// TLB指令相关的变量
	input wire             cp0_entryhi_we,
	input wire [`RegBus]   cp0_entryhi_i,
	input wire             cp0_entrylo0_we,
	input wire [`RegBus]   cp0_entrylo0_i,
	input wire             cp0_entrylo1_we,
	input wire [`RegBus]   cp0_entrylo1_i,
	
	// 异常相关信息
	input wire exception_flag,
	input wire [4:0] excepttype_i,
	input wire exception_inst_sel,
	input wire [`InstAddrBus] inst_addr_i1,
	input wire [`InstAddrBus] inst_addr_i2,
	input wire [`RegBus] mem_addr_i,
	input wire is_in_delayslot_i1,
	input wire is_in_delayslot_i2,
	
	output reg [`RegBus] data_o,
    output reg [`RegBus] index_o,
    output reg [`RegBus] random_o,
    output reg [`RegBus] entrylo0_o,
    output reg [`RegBus] entrylo1_o,
    output reg [`RegBus] entryhi_o,
    output reg [`RegBus] context_o,
    output reg [`RegBus] pagemask_o,
    output reg [`RegBus] wired_o,
	output reg [`RegBus] badvaddr_o,
	output reg [`RegBus] count_o,
	output reg [`RegBus] compare_o,
	output reg [`RegBus] status_o,
	output reg [`RegBus] cause_o,
	output reg [`RegBus] epc_o,
	output reg [`RegBus] config_o,
	output reg [`RegBus] config1_o,
	output reg [`RegBus] ebase_o,
	output reg [`RegBus] prid_o,
	output reg [`RegBus] taglo_o,
	output reg [`RegBus] taghi_o,
	output reg timer_int_o  // 是否有定时中断发生
	
    );
    
    reg [`RegBus] epc;
    reg bd;
    
    // count计时器自增1的频率是处理器核流水线时钟的频率的1/2
    reg clk_2;
    
    // 确定epc和bd字段
    always @ (*) begin
        if (exception_inst_sel && is_in_delayslot_i1 == `InDelaySlot) begin
            epc = inst_addr_i1 - 32'h4;
            bd = 1'b1;
        end else if (exception_inst_sel && is_in_delayslot_i1 == `NotInDelaySlot) begin
            epc = inst_addr_i1;
            bd = 1'b0;
        end else if (~exception_inst_sel && is_in_delayslot_i2 == `InDelaySlot) begin
            epc = inst_addr_i2 - 32'h4;
            bd = 1'b1;
        end else begin
            epc = inst_addr_i2;
            bd = 1'b0;
        end
    end
    
// 第一段：对CP0中寄存器的写操作
    always @ (posedge clk) begin
		if(rst == `RstEnable) begin
            index_o <= `ZeroWord;
            random_o <= `CP0_RANDOM_RST;
            entrylo0_o <= `ZeroWord;
            entrylo1_o <= `ZeroWord;
            entryhi_o <= `ZeroWord;
            context_o <= `ZeroWord;
            pagemask_o <= `ZeroWord;
            wired_o <= `ZeroWord;
            badvaddr_o <= `ZeroWord;
			count_o <= `ZeroWord;
			compare_o <= `ZeroWord;
			status_o <= `CP0_STATUS_RST;
			cause_o <= `ZeroWord;
			epc_o <= `ZeroWord;
			// Config寄存器的初始值，其中BE字段为1，表示工作在大端模式
			config_o <= `CP0_CONFIG_RST;
			config1_o <= `CP0_CONFIG1_RST;
			prid_o <= `CP0_PRID_RST;
			ebase_o <= `CP0_EBASE_RST;
			taglo_o <= `ZeroWord;
			taghi_o <= `ZeroWord;
            timer_int_o <= `InterruptNotAssert;
            clk_2 <= 1'b0;
		end else begin
            clk_2 <= ~clk_2;
            count_o <= clk_2 ? count_o + 1 : count_o;
            cause_o[15:10] <= int_i;
            cause_o[30] <= timer_int_o;
		
			if (compare_o != `ZeroWord && count_o == compare_o) begin
				timer_int_o <= `InterruptAssert;
			end
			
			if (cp0_entrylo0_we) begin
                entrylo0_o[25:0] <= cp0_entrylo0_i[25:0];
            end
            
            if (cp0_entrylo1_we) begin
                entrylo1_o[25:0] <= cp0_entrylo1_i[25:0];
            end
            
            if (cp0_entryhi_we) begin
                entryhi_o[31:13] <= cp0_entryhi_i[31:13];
                entryhi_o[7:0] <= cp0_entryhi_i[7:0];
            end
					
			if(we_i == `WriteEnable) begin
                if (wsel_i == 3'b000) begin
                    case (waddr_i) 
                        `CP0_REG_INDEX:     begin
                            index_o[3:0] <= data_i[3:0];
                        end
                        `CP0_REG_EntryLo0:  begin
                            entrylo0_o[25:0] <= data_i[25:0];
                        end
                        `CP0_REG_EntryLo1:  begin
                            entrylo1_o[25:0] <= data_i[25:0];
                        end
                        `CP0_REG_CONTEXT:   begin
                            context_o[31:23] <= data_i[31:23];
                        end
                        `CP0_REG_PAGEMASK:  begin
                            pagemask_o[28:13] <= data_i[28:13];
                        end
                        `CP0_REG_WIRED:     begin
                            wired_o[3:0] <= data_i[3:0];
                            random_o <= `CP0_RANDOM_RST;  // 写Wired寄存器会初始化Random寄存器
                        end
                        `CP0_REG_COUNT:     begin
                            clk_2 <= 1'b0;
                            count_o <= data_i;
                        end
                        `CP0_REG_EntryHi:   begin
                            entryhi_o[31:13] <= data_i[31:13];
                            entryhi_o[7:0] <= data_i[7:0];
                        end
                        `CP0_REG_COMPARE:  begin
                            compare_o <= data_i;
                            //count_o <= `ZeroWord;
                            timer_int_o <= `InterruptNotAssert;
                        end
                        `CP0_REG_STATUS:   begin
                            status_o[15:8] <= data_i[15:8];
                            status_o[1:0] <= data_i[1:0];
                        end
                        `CP0_REG_EPC:	begin
                            epc_o <= data_i;
                        end
                        `CP0_REG_CAUSE:	begin
                            cause_o[9:8] <= data_i[9:8];
                        end	
                        `CP0_REG_TagLo: begin
                            taglo_o[21:0] <= data_i[21:0];  // 低22位分别为D、V、Tag
                        end
                        `CP0_REG_TagHi: begin
                            taghi_o[21:0] <= data_i[21:0];
                        end
                        default:   ;				
                    endcase  //case waddr_i
                end
                else if (wsel_i == 3'b001) begin
                    case (waddr_i)
                        `CP0_REG_EBase: ebase_o <= data_i;
                        default:    ;
                    endcase
                end
            end
			
			if (exception_flag) begin
                case (excepttype_i)
                    `EXCEPTION_INT: begin
                        epc_o <= epc;
                        cause_o[31] <= bd;
                        status_o[1] <= 1'b1;
                        cause_o[6:2] <= excepttype_i;
                    end
                    `EXCEPTION_ADEL: begin
                        epc_o <= epc;
                        cause_o[31] <= bd;
                        status_o[1] <= 1'b1;
                        cause_o[6:2] <= excepttype_i;
                        if (|inst_addr_i1[1:0]) badvaddr_o = inst_addr_i1;
                        else if (|inst_addr_i2[1:0]) badvaddr_o = inst_addr_i2;
                        else badvaddr_o = mem_addr_i;
                    end
                    `EXCEPTION_ADES: begin
                        epc_o <= epc;
                        cause_o[31] <= bd;
                        status_o[1] <= 1'b1;
                        cause_o[6:2] <= excepttype_i;
                        badvaddr_o = mem_addr_i;
                    end
                    `EXCEPTION_SYS: begin
                        epc_o <= epc;
                        cause_o[31] <= bd;
                        status_o[1] <= 1'b1;
                        cause_o[6:2] <= excepttype_i;
                    end
                    `EXCEPTION_BP: begin
                        epc_o <= epc;
                        cause_o[31] <= bd;
                        status_o[1] <= 1'b1;
                        cause_o[6:2] <= excepttype_i;
                    end
                    `EXCEPTION_RI: begin
                        epc_o <= epc;
                        cause_o[31] <= bd;
                        status_o[1] <= 1'b1;
                        cause_o[6:2] <= excepttype_i;
                    end
                    `EXCEPTION_OV: begin
                        epc_o <= epc;
                        cause_o[31] <= bd;
                        status_o[1] <= 1'b1;
                        cause_o[6:2] <= excepttype_i;
                    end
                    `EXCEPTION_TR: begin
                        epc_o <= epc;
                        cause_o[31] <= bd;
                        status_o[1] <= 1'b1;
                        cause_o[6:2] <= excepttype_i;
                    end
                    `EXCEPTION_ERET: 
                        status_o[1] <= 1'b0;
                    default: ;
                endcase  // case excepttype_i
            end  // if
		end  //  if
    end  //  always
    
// 第二段：对CP0中寄存器的读操作
    always @ (*) begin
        if(rst == `RstEnable) begin
            data_o = `ZeroWord;
        end else begin
            if (rsel_i == 3'b000) begin
                case (raddr_i)
                    `CP0_REG_INDEX:     data_o = index_o;
                    `CP0_REG_RANDOM:    data_o = random_o;
                    `CP0_REG_EntryLo0:  data_o = entrylo0_o;
                    `CP0_REG_EntryLo1:  data_o = entrylo1_o;
                    `CP0_REG_CONTEXT:   data_o = context_o;
                    `CP0_REG_PAGEMASK:  data_o = pagemask_o;
                    `CP0_REG_WIRED:     data_o = wired_o;
                    `CPO_REG_BADVADDR:  data_o = badvaddr_o;
                    `CP0_REG_COUNT:     data_o = count_o ;
                    `CP0_REG_EntryHi:   data_o = entryhi_o;
                    `CP0_REG_COMPARE:   data_o = compare_o ;
                    `CP0_REG_STATUS:    data_o = status_o ;
                    `CP0_REG_CAUSE:     data_o = cause_o ;
                    `CP0_REG_EPC:       data_o = epc_o ;
                    `CP0_REG_PRId:      data_o = prid_o ;
                    `CP0_REG_CONFIG:    data_o = config_o ;
                    `CP0_REG_TagLo:     data_o = taglo_o;
                    `CP0_REG_TagHi:     data_o = taghi_o;
                    default:            data_o = `ZeroWord;
                endcase  //case raddr_i            
            end else if (rsel_i == 3'b001) begin
                case (raddr_i)
                    `CP0_REG_EBase:     data_o = ebase_o;
                    `CP0_REG_CONFIG1:   data_o = config1_o;
                    default:            data_o = `ZeroWord;
                endcase
            end else data_o = `ZeroWord;
        end // if
    end  //always
endmodule
