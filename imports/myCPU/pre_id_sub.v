`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/01 15:39:08
// Design Name: 
// Module Name: pre_id_sub
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


module pre_id_sub(

    input wire rst,
    input wire [`RegBus] inst_i,
//    input wire inst_valid,
    output reg [1:0] inst_type,
    output reg [31:0] inst_offset
//    output reg pcr_call
    
    );
    
    wire [5:0] op = inst_i[31:26];
    wire [4:0] op2 = inst_i[10:6];
    wire [5:0] op3 = inst_i[5:0];
    wire [4:0] op4 = inst_i[20:16];
    
    always @(*) begin
        if (rst == `RstEnable) begin
            inst_type = `TYPE_NUL;
            inst_offset = 32'b0;
//            pcr_call = 1'b0;
        end else begin
            inst_type = `TYPE_NUL;
            inst_offset = 32'b0;
//            pcr_call = 1'b0;
            case (op)
                `EXE_SPECIAL_INST:  begin
                    case (op3)
                        `EXE_JR:    inst_type = `TYPE_RET;
                        `EXE_JALR:  inst_type = `TYPE_NUL;
                        default:    ;
                    endcase  // case op3
                end                                      
                `EXE_J,`EXE_JAL:    begin
                    inst_type = `TYPE_CALL;
                    inst_offset = {4'h0, inst_i[25:0], 2'b00};
                end
                `EXE_BEQ:   begin
//                    inst_type = ~|inst_i[25:21] & ~|inst_i[20:16] ? `TYPE_CALL : `TYPE_PCR;
                    inst_type = `TYPE_PCR;
                    inst_offset = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};
//                    pcr_call = inst_valid ? ~|inst_i[25:21] & ~|inst_i[20:16] : 1'b0;
                end
                `EXE_BGTZ, `EXE_BLEZ, `EXE_BNE:   begin
                    inst_type = `TYPE_PCR;
                    inst_offset = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};
                end
                `EXE_REGIMM_INST:   begin
                    case (op4)
                        `EXE_BGEZ, `EXE_BLTZ:   begin
                            inst_type = `TYPE_PCR;
                            inst_offset = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};
                        end
                        `EXE_BGEZAL:    begin
//                            inst_type = ~|inst_i[25:21] ? `TYPE_CALL : `TYPE_PCR;
                            inst_type = `TYPE_PCR;
                            inst_offset = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};
//                            pcr_call = inst_valid ? ~|inst_i[25:21] : 1'b0;
                        end
                        `EXE_BLTZAL:    begin
                            inst_type = `TYPE_PCR;
                            inst_offset = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};
                        end
                        default:    ;
                    endcase  // case op4
                end
                default: ;
            endcase  //case op
        end
    end
endmodule
