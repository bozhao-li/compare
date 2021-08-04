`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/09 14:50:17
// Design Name: 
// Module Name: regfile
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


// Regfile模块实现32个32位通用寄存器，可以同时进行四个寄存器的读操作和两个寄存器的写操作
module regfile(
    input wire clk,
    input wire rst,
    
    // 写端口1
    input wire we1,  // 写使能信号
    input wire [`RegAddrBus] waddr1,
    input wire [`RegBus] wdata1,   
    // 写端口2
    input wire we2,
    input wire [`RegAddrBus] waddr2,
    input wire [`RegBus] wdata2,
    
    // 读使能信号需要吗？
    // 读端口1
    input wire re1,
    input wire [`RegAddrBus] raddr1,
    output reg [`RegBus] rdata1,
    // 读端口2
    input wire re2,
    input wire [`RegAddrBus] raddr2,
    output reg [`RegBus] rdata2,
    // 读端口3
    input wire re3,
    input wire [`RegAddrBus] raddr3,
    output reg [`RegBus] rdata3,
    // 读端口4
    input wire re4,
    input wire [`RegAddrBus] raddr4,
    output reg [`RegBus] rdata4
    );
    
    reg [`RegBus] regs [0:`RegNum-1];  // 定义32个32位寄存器
       
    // 写操作
    integer i;
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            for (i = 0; i < 32; i=i+1)  regs[i] <= `ZeroWord;
        end else begin
            case ({we2,we1})
                {`WriteDisable,`WriteEnable}:
                    if (waddr1 != `RegNumLog2'h0)
                        regs[waddr1] <= wdata1;  // 写使能有效且要写入的寄存器地址不为0
                {`WriteEnable,`WriteDisable}:
                    if (waddr2 != `RegNumLog2'h0)
                        regs[waddr2] <= wdata2;
                {`WriteEnable,`WriteEnable}: begin
                    if (waddr2 != `RegNumLog2'h0)
                        regs[waddr2] <= wdata2;  // 2为双发射中后一条指令，所以在WAW相关中只写2就行
                    if (waddr1 != waddr2 && waddr1 != `RegNumLog2'h0)
                        regs[waddr1] <= wdata1;  // 不存在WAW相关则写1
                end
                default: ;
            endcase
        end
    end
    
    // 读端口1的读操作
    always @ (*) begin
        if (rst == `RstEnable) begin
            rdata1 = `ZeroWord;
        end else if (raddr1 == `RegNumLog2'h0) begin
            rdata1 = `ZeroWord;
        end else begin
            case ({we2,we1})
                {`WriteDisable,`WriteEnable}:
                    rdata1 = (re1 == `ReadEnable && raddr1 == waddr1) ? wdata1 : regs[raddr1];
                {`WriteEnable,`WriteDisable}:
                    rdata1 = (re1 == `ReadEnable && raddr1 == waddr2) ? wdata2 : regs[raddr1];
                {`WriteEnable,`WriteEnable}: begin
                    if (re1 == `ReadEnable) begin
                        if (raddr1 == waddr2)  rdata1 = wdata2;  // 2的优先级最大
                        else if (raddr1 == waddr1)  rdata1 = wdata1;
                        else rdata1 = regs[raddr1];
                    end else
                        rdata1 = `ZeroWord;
                end
                default: 
                    rdata1 = (re1 == `ReadEnable) ? regs[raddr1] : `ZeroWord;
            endcase
        end
    end
    
    // 读端口2的读操作
    always @ (*) begin
        if (rst == `RstEnable) begin
            rdata2 = `ZeroWord;
        end else if (raddr2 == `RegNumLog2'h0) begin
            rdata2 = `ZeroWord;
        end else begin
            case ({we2,we1})
                {`WriteDisable,`WriteEnable}:
                    rdata2 = (re2 == `ReadEnable && raddr2 == waddr1) ? wdata1 : regs[raddr2];
                {`WriteEnable,`WriteDisable}:
                    rdata2 = (re2 == `ReadEnable && raddr2 == waddr2) ? wdata2 : regs[raddr2];
                {`WriteEnable,`WriteEnable}: begin
                    if (re2 == `ReadEnable) begin
                        if (raddr2 == waddr2)  rdata2 = wdata2;  // 2的优先级最大
                        else if (raddr2 == waddr1)  rdata2 = wdata1;
                        else rdata2 = regs[raddr2];
                    end else
                        rdata2 = `ZeroWord;
                end
                default:
                    rdata2 = (re2 == `ReadEnable) ? regs[raddr2] : `ZeroWord; 
            endcase
        end
    end
    
    // 读端口3的读操作
    always @ (*) begin
        if (rst == `RstEnable) begin
            rdata3 = `ZeroWord;
        end else if (raddr3 == `RegNumLog2'h0) begin
            rdata3 = `ZeroWord;
        end else begin
            case ({we2,we1})
                {`WriteDisable,`WriteEnable}:
                    rdata3 = (re3 == `ReadEnable && raddr3 == waddr1) ? wdata1 : regs[raddr3];
                {`WriteEnable,`WriteDisable}:
                    rdata3 = (re3 == `ReadEnable && raddr3 == waddr2) ? wdata2 : regs[raddr3];
                {`WriteEnable,`WriteEnable}: begin
                    if (re3 == `ReadEnable) begin
                        if (raddr3 == waddr2)  rdata3 = wdata2;  // 2的优先级最大
                        else if (raddr3 == waddr1)  rdata3 = wdata1;
                        else rdata3 = regs[raddr3];
                    end else
                        rdata3 = `ZeroWord;
                end
                default:
                    rdata3 = (re3 == `ReadEnable) ? regs[raddr3] : `ZeroWord; 
            endcase
        end
    end
    
    // 读端口4的读操作
    always @ (*) begin
        if (rst == `RstEnable) begin
            rdata4 = `ZeroWord;
        end else if (raddr4 == `RegNumLog2'h0) begin
            rdata4 = `ZeroWord;
        end else begin
            case ({we2,we1})
                {`WriteDisable,`WriteEnable}:
                    rdata4 = (re4 == `ReadEnable && raddr4 == waddr1) ? wdata1 : regs[raddr4];
                {`WriteEnable,`WriteDisable}:
                    rdata4 = (re4 == `ReadEnable && raddr4 == waddr2) ? wdata2 : regs[raddr4];
                {`WriteEnable,`WriteEnable}: begin
                    if (re4 == `ReadEnable) begin
                        if (raddr4 == waddr2)  rdata4 = wdata2;  // 2的优先级最大
                        else if (raddr4 == waddr1)  rdata4 = wdata1;
                        else rdata4 = regs[raddr4];
                    end else
                        rdata4 = `ZeroWord;
                end
                default:
                    rdata4 = (re4 == `ReadEnable) ? regs[raddr4] : `ZeroWord; 
            endcase
        end
    end
    
endmodule