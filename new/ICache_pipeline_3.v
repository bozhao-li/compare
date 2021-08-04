`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/30 21:46:13
// Design Name: 
// Module Name: ICache_pipeline_3
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


module ICache_pipeline_3(

    input wire clk,
    input wire rst,
    input wire iuncache_i,
    output wire stall, 
    input wire flush,
    
    //Cache port with CPU
    input wire valid,           //valid request
    input wire [31:0] vaddr_i1,
    input wire [31:0] vaddr_i2,
    input wire [31:0] paddr_i,
    output wire data_ok1,       //data transfer out is OK
    output wire data_ok2,
    output reg [31:0] rdata1,
    output reg [31:0] rdata2,
    output reg [31:0] raddr1,
    output reg [31:0] raddr2,
    
    // with BPU
    input wire ex_branch_flag,
	input wire predict_success,
	input wire [31:0] ex_inst_addr_i1,
	input wire [34:0] corr_pkt,
    input wire instbuffer_full,
    output wire [34:0] predict_pkto1,
    output wire [34:0] predict_pkto2,
    output reg [31:0] icache_npc,
    
    //Cache port with AXI
    output reg iuncache_s2,
    output wire [7:0] rd_len,
    output wire rd_req,          //read valid request
    output wire [31:0] rd_addr,  //read initial address
    input wire ret_valid,        //return data valid
    input wire [127:0] ret_data
    
    );
    
// stage 1
    wire valid_s1 = valid;
    wire [19:0] ptag_s1 = paddr_i[31:12];
    wire [7:0] index_s1 = paddr_i[11:4];
    reg  [7:0] index_s2;
    reg [19:0] ptag_s2;
    wire [3:0] offset_s1 = paddr_i[3:0];
    wire [31:0] vaddr_i1_s1 = vaddr_i1;
    wire [31:0] vaddr_i2_s1 = vaddr_i2;
    
    // first branch predict
    wire [31:0] predict_pta1_s1, predict_pta2_s1;
    wire predict_dir1_s1 = |predict_pta1_s1;
    wire predict_dir2_s1 = |predict_pta2_s1;
    
    // hit judge
    wire [20:0] way0_tagv;
    wire wea_way0;
    
    wire [20:0] way1_tagv;
    wire wea_way1;
    
    wire hit_judge_way0_s1 = (wea_way0 && index_s1 == index_s2 && ptag_s1 == ptag_s2) ? 1'b1 : 
                            (way0_tagv[20] != 1'b1) ? 1'b0 : 
                            (ptag_s1 == way0_tagv[19:0]) ? 1'b1 : 
                            1'b0;
    wire hit_judge_way1_s1 = (wea_way1 && index_s1 == index_s2 && ptag_s1 == ptag_s2) ? 1'b1 : 
                            (way1_tagv[20] != 1'b1) ? 1'b0 : 
                            (ptag_s1 == way1_tagv[19:0]) ? 1'b1 : 
                            1'b0;
                            
    wire hit_s1 = (hit_judge_way0_s1 | hit_judge_way1_s1) && valid_s1 && !iuncache_i;
    wire nhit_s1 = iuncache_i ? 1'b1 : 
                    ((wea_way0 | wea_way1) && index_s1 == index_s2 && ptag_s1 == ptag_s2) ? 1'b0 :
                    ~(hit_judge_way0_s1 | hit_judge_way1_s1) & valid_s1;  
    
    
        
// stage 2
    reg [3:0] offset_s2;
    reg [31:0] vaddr_i1_s2;
    reg [31:0] vaddr_i2_s2;
    reg instbuffer_full_s2;
    wire flush_s2;
    
    // first branch predict: s2
    reg [31:0] predict_pta1_s2, predict_pta2_s2;
    reg predict_dir1_s2, predict_dir2_s2;
    reg hit_s2;
    reg nhit_s2;
    reg hit_judge_way0_s2, hit_judge_way1_s2;
    
    // from stage1 to stage2
    always@(posedge clk)begin
        if(~rst | flush)begin
            ptag_s2 <= 20'b0;
            index_s2 <= 8'b0;
            offset_s2 <= 4'b0;
            vaddr_i1_s2 <= 32'h0;
            vaddr_i2_s2 <= 32'h0;
            iuncache_s2 <= 1'b0;
            predict_pta1_s2 <= 32'b0;
            predict_pta2_s2 <= 32'b0;
            predict_dir1_s2 <= 1'b0;
            predict_dir2_s2 <= 1'b0;
            hit_s2 <= 1'b0;
            nhit_s2 <= 1'b0;
            hit_judge_way0_s2 <= 1'b0;
            hit_judge_way1_s2 <= 1'b0;
            instbuffer_full_s2 <= 1'b0;            
        end else if(stall)begin
            ptag_s2 <= ptag_s2;
            index_s2 <= index_s2;
            offset_s2 <= offset_s2;
            vaddr_i1_s2 <= vaddr_i1_s2;
            vaddr_i2_s2 <= vaddr_i2_s2;
            iuncache_s2 <= iuncache_s2;
            predict_pta1_s2 <= predict_pta1_s2;
            predict_pta2_s2 <= predict_pta2_s2;
            predict_dir1_s2 <= predict_dir1_s2;
            predict_dir2_s2 <= predict_dir2_s2;
            hit_s2 <= hit_s2;
            nhit_s2 <= nhit_s2;
            hit_judge_way0_s2 <= hit_judge_way0_s2;
            hit_judge_way1_s2 <= hit_judge_way1_s2;
            instbuffer_full_s2 <= instbuffer_full_s2; 
        end else begin
            ptag_s2 <= ptag_s1;
            index_s2 <= index_s1;
            offset_s2 <= offset_s1;
            vaddr_i1_s2 <= vaddr_i1_s1;
            vaddr_i2_s2 <= vaddr_i2_s1;
            iuncache_s2 <= iuncache_i;
            predict_pta1_s2 <= predict_pta1_s1;
            predict_pta2_s2 <= predict_pta2_s1;
            predict_dir1_s2 <= predict_dir1_s1;
            predict_dir2_s2 <= predict_dir2_s1;
            hit_s2 <= hit_s1;
            nhit_s2 <= nhit_s1;
            hit_judge_way0_s2 <= hit_judge_way0_s1;
            hit_judge_way1_s2 <= hit_judge_way1_s1;
            instbuffer_full_s2 <= instbuffer_full;
        end
    end
    
    wire [31:0]read_from_AXI[3:0];
    for(genvar i = 0 ;i < 4; i = i+1) begin
        assign read_from_AXI[i] = ret_data[32*(i+1)-1:32*i];
    end
    
    // cache define
    wire [7:0] read_addr = stall ? index_s2 : index_s1;
    
    wire [31:0] way0_cacheline[3:0];
    wire read_enb0 = ~(wea_way0 && index_s2 == read_addr);
    dram_tagv tagv_way0(.a(index_s2), .d({1'b1, ptag_s2}), .dpra(index_s1), .clk(clk), .we(wea_way0), .dpo(way0_tagv));
    Data_dual_ram Bank0_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[0]), .enb(read_enb0));
    Data_dual_ram Bank1_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[1]), .enb(read_enb0));
    Data_dual_ram Bank2_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[2]), .enb(read_enb0));
    Data_dual_ram Bank3_way0(.addra(index_s2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[3]), .enb(read_enb0));

    wire [31:0] way1_cacheline[3:0];
    wire read_enb1 = ~(wea_way1 && index_s2 == read_addr);   
    dram_tagv tagv_way1(.a(index_s2), .d({1'b1, ptag_s2}), .dpra(index_s1), .clk(clk), .we(wea_way1), .dpo(way1_tagv));
    Data_dual_ram Bank0_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[0]), .enb(read_enb1));
    Data_dual_ram Bank1_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[1]), .enb(read_enb1));
    Data_dual_ram Bank2_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[2]), .enb(read_enb1));
    Data_dual_ram Bank3_way1(.addra(index_s2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[3]), .enb(read_enb1));
    
    // data_ok                                   
    wire data_ok1_s2_temp = (iuncache_s2 && ret_valid) ? 1'b1 :
                            hit_s2 ? 1'b1 : (nhit_s2 && ret_valid);
                       
    wire data_ok2_s2_temp = (iuncache_s2 && ret_valid) ? 1'b0 :
                            (offset_s2[3:2] == 2'b11) ? 1'b0 : 
                            data_ok1_s2_temp;
                            
    wire data_ok1_s2, data_ok2_s2;
                            
    // valid_flush
    wire fpredict_flag1, fpredict_flag2;
    reg predict_dir1_s3, predict_dir2_s3;
    reg spredict_dir1, spredict_dir2;
    
    wire predict_en_s3 = ~stall & ~instbuffer_full_s2;
    reg  predict_en1_s2;
    always @(posedge clk) begin
        if (~rst | flush)
            predict_en1_s2 <= 1'b1;
        else if (~fpredict_flag1 & stall & data_ok2)
            predict_en1_s2 <= 1'b0;
        else if (data_ok1_s2_temp)
            predict_en1_s2 <= 1'b1;
    end
    
    reg predict_en2_s2;
    always @(posedge clk) begin
        if (~rst | flush)
            predict_en2_s2 <= 1'b1;
        else if ((spredict_dir1 ^ predict_dir1_s3) & data_ok2 & stall)
            predict_en2_s2 <= 1'b0;
        else if (spredict_dir1 & ~predict_dir1_s3 & data_ok1 & stall)
            predict_en2_s2 <= 1'b0;
        else if (spredict_dir2 & ~predict_dir2_s3 & data_ok2 & stall)
            predict_en2_s2 <= 1'b0;
        else if (data_ok1_s2_temp)
            predict_en2_s2 <= 1'b1;
    end
    
    reg inst_valid1_s2, inst_valid2_s2;
    reg inst_valid1_s3, inst_valid2_s3;
    always @(posedge clk) begin
        if (~rst | flush) begin
            inst_valid1_s2 <= 1'b1;
            inst_valid2_s2 <= 1'b1;
        end else if (~fpredict_flag1 & data_ok1 & predict_en_s3) begin
            inst_valid1_s2 <= 1'b0;
            inst_valid2_s2 <= 1'b0;
        end else if (~fpredict_flag2 & data_ok2 & predict_en_s3) begin
            inst_valid1_s2 <= 1'b0;
            inst_valid2_s2 <= 1'b0;
        end else if (predict_dir1_s2 & data_ok1_s2 & ~data_ok2_s2 & predict_en1_s2) begin
            inst_valid1_s2 <= 1'b1;
            inst_valid2_s2 <= 1'b0;
        end else if (predict_dir2_s2 & data_ok2_s2 & predict_en2_s2) begin
            inst_valid1_s2 <= 1'b1;
            inst_valid2_s2 <= 1'b0;
        end else if (data_ok1_s2_temp) begin
            inst_valid1_s2 <= 1'b1;
            inst_valid2_s2 <= 1'b1;
        end
    end
    
    // keep pta
    reg keep_pta;
    always @(posedge clk) begin
        if (~rst | flush) keep_pta <= 1'b0;
        else if (~fpredict_flag1 & data_ok1)                            keep_pta <= 1'b1;
        else if (~fpredict_flag2 & data_ok2)                            keep_pta <= 1'b1;   
        else if (predict_dir1_s2 & data_ok1_s2 & ~data_ok2_s2)          keep_pta <= 1'b1;
        else if (predict_dir2_s2 & data_ok2_s2)                         keep_pta <= 1'b1;
        else if (predict_dir1_s1 & ~(iuncache_i | &offset_s1[3:2]))     keep_pta <= 1'b1;
        else if (data_ok1_s2_temp)                                      keep_pta <= 1'b0;
    end
    
    assign data_ok1_s2 = data_ok1_s2_temp & inst_valid1_s2;
    assign data_ok2_s2 = data_ok2_s2_temp & inst_valid2_s2;
    
    // LRU 
    reg [255:0] LRU;    //LRU width depends on index
    wire LRU_current = LRU[index_s2];
    always@(posedge clk)begin
        if(~rst)begin
            LRU <= 256'b0;
        end else if(data_ok1_s2_temp && hit_s2)begin
            LRU[index_s2] <= hit_judge_way0_s2;
        end else if(data_ok1_s2_temp && !hit_s2)begin
            LRU[index_s2] <= wea_way0;
        end else begin
            LRU <= LRU;
        end
    end
    
    // collision 
    reg collision_way0;
    reg collision_way1;
    reg [31:0]inst1_from_mem_s2;
    reg [31:0]inst2_from_mem_s2;
    
    always@(posedge clk)begin
        collision_way0 <= (wea_way0 && index_s1 == index_s2);
        collision_way1 <= (wea_way1 && index_s1 == index_s2);
        inst1_from_mem_s2 <= read_from_AXI[offset_s1[3:2]];
        inst2_from_mem_s2 <= read_from_AXI[offset_s1[3:2]+2'h1];
    end
    
    // inner logics
    assign wea_way0 = (ret_valid && LRU_current == 1'b0 && ~iuncache_s2);
    assign wea_way1 = (ret_valid && LRU_current == 1'b1 && ~iuncache_s2);
    
    //data select
    wire [31:0] inst1_way0 = collision_way0 ? inst1_from_mem_s2 : way0_cacheline[offset_s2[3:2]];
    wire [31:0] inst2_way0 = ~(|vaddr_i2_s2[3:0]) ? 32'b0 : collision_way0 ? inst2_from_mem_s2 : way0_cacheline[offset_s2[3:2] + 2'b1];
    wire [31:0] inst1_way1 = collision_way1 ? inst1_from_mem_s2 : way1_cacheline[offset_s2[3:2]];
    wire [31:0] inst2_way1 = ~(|vaddr_i2_s2[3:0]) ? 32'b0 : collision_way1 ? inst2_from_mem_s2 : way1_cacheline[offset_s2[3:2] + 2'b1];
    
    // rdata
    wire [31:0] rdata1_s2 = (iuncache_s2 && ret_valid) ? ret_data[31:0] :
                            (hit_s2 && hit_judge_way0_s2) ? inst1_way0 : 
                            (hit_s2 && hit_judge_way1_s2) ? inst1_way1 :
                            (nhit_s2 && ret_valid && offset_s2[3:2] == 2'h0) ? read_from_AXI[0] :
                            (nhit_s2 && ret_valid && offset_s2[3:2] == 2'h1) ? read_from_AXI[1] :
                            (nhit_s2 && ret_valid && offset_s2[3:2] == 2'h2) ? read_from_AXI[2] :
                            (nhit_s2 && ret_valid && offset_s2[3:2] == 2'h3) ? read_from_AXI[3] :
                            32'b0;
    
    wire [31:0] rdata2_s2 = (hit_s2 && hit_judge_way0_s2) ? inst2_way0 : 
                             (hit_s2 && hit_judge_way1_s2) ? inst2_way1 :
                             (nhit_s2 && ret_valid && offset_s2[3:2] == 2'h0) ? read_from_AXI[1] :
                             (nhit_s2 && ret_valid && offset_s2[3:2] == 2'h1) ? read_from_AXI[2] :
                             (nhit_s2 && ret_valid && offset_s2[3:2] == 2'h2) ? read_from_AXI[3] :
                             (nhit_s2 && ret_valid && offset_s2[3:2] == 2'h3) ? read_from_AXI[0] :
                             32'b0;

    // output logics    
    assign rd_len = (iuncache_s2 & rd_req) ? 8'h0 : 8'h3;
    
    assign rd_req = (nhit_s2 && !ret_valid);

    assign rd_addr = iuncache_s2 ? {ptag_s2, index_s2, offset_s2} : {ptag_s2, index_s2, 4'b0};
    
    assign stall = (iuncache_s2 & ~data_ok1_s2_temp) ? 1'b1 :
                   (nhit_s2 & ~data_ok1_s2_temp);
                   
   // second branch predict
    wire spredict_dir1_s2, spredict_dir2_s2;
    wire [31:0] spredict_pta1_s2, spredict_pta2_s2;
                   
// stage 3

    // second branch predict
    reg [31:0] spredict_pta1, spredict_pta2;
    
    // from stage2 to stage3
    reg [31:0] predict_pta1_s3, predict_pta2_s3;   
    reg data_ok1_s3, data_ok2_s3; 
    
    always @(posedge clk) begin
        if(~rst | flush)begin
            data_ok1_s3 <= 1'b0;
            data_ok2_s3 <= 1'b0;
            rdata1 <= 32'b0;
            rdata2 <= 32'b0;
            raddr1 <= 32'b0;
            raddr2 <= 32'b0;
            predict_dir1_s3 <= 1'b0;
            predict_dir2_s3 <= 1'b0;
            predict_pta1_s3 <= 32'b0;
            predict_pta2_s3 <= 32'b0; 
            spredict_dir1 <= 1'b0;
            spredict_dir2 <= 1'b0;
            spredict_pta1 <= 32'b0;
            spredict_pta2 <= 32'b0;        
        end else if (data_ok1_s2) begin
            data_ok1_s3 <= data_ok1_s2;
            data_ok2_s3 <= data_ok2_s2;
            rdata1 <= rdata1_s2;
            rdata2 <= rdata2_s2;
            raddr1 <= vaddr_i1_s2;
            raddr2 <= vaddr_i2_s2;
            predict_dir1_s3 <= predict_dir1_s2;
            predict_dir2_s3 <= predict_dir2_s2;
            predict_pta1_s3 <= predict_pta1_s2;
            predict_pta2_s3 <= predict_pta2_s2;   
            spredict_dir1 <= spredict_dir1_s2;
            spredict_dir2 <= spredict_dir2_s2;
            spredict_pta1 <= spredict_pta1_s2;
            spredict_pta2 <= spredict_pta2_s2;
        end else begin
            data_ok1_s3 <= 1'b0;
            data_ok2_s3 <= 1'b0;
        end
    end        
    
    bpu bpu0(
        .clk(clk),
        .rst(rst),
        
        .first_inst_addr1(vaddr_i1),
        .first_inst_addr2(vaddr_i2),
        .first_predict_inst_addr1(predict_pta1_s1),
        .first_predict_inst_addr2(predict_pta2_s1),
        
        // on stage2
        .second_inst_addr1(vaddr_i1_s2),
        .second_inst1(rdata1_s2),
        .second_inst_addr2(vaddr_i2_s2),
        .second_inst2(rdata2_s2),
        
        .second_branch_predict_happen1(spredict_dir1_s2),
        .second_branch_predict_happen2(spredict_dir2_s2),
        .second_predict_inst_addr1(spredict_pta1_s2),
        .second_predict_inst_addr2(spredict_pta2_s2),
        
        // on stage3
//        .second_inst_addr1(raddr1),
//        .second_inst1(rdata1),
//        .second_inst_addr2(raddr2),
//        .second_inst2(rdata2),
        
//        .second_branch_predict_happen1(spredict_dir1),
//        .second_branch_predict_happen2(spredict_dir2),
//        .second_predict_inst_addr1(spredict_pta1),
//        .second_predict_inst_addr2(spredict_pta2),
    
        .ex_branch_type(corr_pkt[1:0]),
        .ex_branch_success(ex_branch_flag), 
        .ex_inst_addr(ex_inst_addr_i1),
        .ex_next_inst_addr(corr_pkt[33:2]),
        .ex_predict_success(predict_success)
    );
    
    assign fpredict_flag1 = data_ok1 ? (predict_dir1_s3 && spredict_dir1 && predict_pta1_s3 == spredict_pta1) ||
                            (~predict_dir1_s3 & ~spredict_dir1) : 1'b1;
    assign fpredict_flag2 = data_ok2 ? (predict_dir2_s3 && spredict_dir2 && predict_pta2_s3 == spredict_pta2) ||
                            (~predict_dir2_s3 & ~spredict_dir2) : 1'b1;
                            
    always @(posedge clk) begin
        if (~rst | flush) begin
            inst_valid1_s3 <= 1'b1;
            inst_valid2_s3 <= 1'b1;
        end else if (~spredict_dir1 & predict_dir1_s3 & data_ok2) begin
            inst_valid1_s3 <= 1'b0;
            inst_valid2_s3 <= 1'b0;
        end else if (spredict_dir1 & ~predict_dir1_s3 & data_ok2) begin
            inst_valid1_s3 <= 1'b0;
            inst_valid2_s3 <= 1'b0;
        end else if (spredict_dir1 & ~predict_dir1_s3 & data_ok1) begin
            inst_valid1_s3 <= 1'b1;
            inst_valid2_s3 <= 1'b0;
        end else if (spredict_dir2 & ~predict_dir2_s3 & data_ok2) begin
            inst_valid1_s3 <= 1'b1;
            inst_valid2_s3 <= 1'b0;
        end else if (data_ok1_s3) begin
            inst_valid1_s3 <= 1'b1;
            inst_valid2_s3 <= 1'b1;
        end
    end 
    
    // output logics
    assign predict_pkto1 = {spredict_dir1, spredict_pta1, 2'b00};
    assign predict_pkto2 = {spredict_dir2, spredict_pta2, 2'b00};
    assign data_ok1 = inst_valid1_s3 & data_ok1_s3;
    assign data_ok2 = inst_valid2_s3 & data_ok2_s3;
    
    // icache_npc
    reg [31:0] icache_npc_ff;
    always @(posedge clk) begin
        if (~rst | flush) 
            icache_npc_ff <= 32'b0;
        else 
            icache_npc_ff <= icache_npc;
    end
    
    always @(*) begin
        if (~rst)                                                                       icache_npc = 32'hbfc00000;
        else if (~fpredict_flag1 & data_ok1)                                            icache_npc = spredict_pta1;
        else if (~fpredict_flag2 & data_ok2)                                            icache_npc = spredict_pta2;     
        else if (predict_dir1_s2 & data_ok1_s2 & ~data_ok2_s2 & predict_en1_s2)         icache_npc = predict_pta1_s2;
        else if (predict_dir2_s2 & data_ok2_s2 & predict_en2_s2)                        icache_npc = predict_pta2_s2;
        else if (instbuffer_full_s2)                                                    icache_npc = icache_npc_ff;
        else if (iuncache_s2 & ~keep_pta)                                               icache_npc = vaddr_i2_s2;
        else if (stall)                                                                 icache_npc = vaddr_i1;
        else if (predict_dir1_s1 & ~(iuncache_i | &offset_s1[3:2]))                     icache_npc = predict_pta1_s1;
        else if (&offset_s1[3:2])                                                       icache_npc = vaddr_i1 + 32'h4;
        else                                                                            icache_npc = vaddr_i1 + 32'h8;
    end
endmodule
