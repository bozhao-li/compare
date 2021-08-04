`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/01 19:27:12
// Design Name: 
// Module Name: mycpu_top
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

module mycpu_top(

    input wire aclk,
	input wire aresetn,
    input wire[5:0] ext_int,
    
    //axi
    //ar
    output [3 :0] arid         ,
    output [31:0] araddr       ,
    output [7 :0] arlen        ,
    output [2 :0] arsize       ,
    output [1 :0] arburst      ,
    output [1 :0] arlock       ,
    output [3 :0] arcache      ,
    output [2 :0] arprot       ,
    output        arvalid      ,
    input         arready      ,
    //r           
    input  [3 :0] rid          ,
    input  [31:0] rdata        ,
    input  [1 :0] rresp        ,
    input         rlast        ,
    input         rvalid       ,
    output        rready       ,
    //aw          
    output [3 :0] awid         ,
    output [31:0] awaddr       ,
    output [7 :0] awlen        ,
    output [2 :0] awsize       ,
    output [1 :0] awburst      ,
    output [1 :0] awlock       ,
    output [3 :0] awcache      ,
    output [2 :0] awprot       ,
    output        awvalid      ,
    input         awready      ,
    //w          
    output [3 :0] wid          ,
    output [31:0] wdata        ,
    output [3 :0] wstrb        ,
    output        wlast        ,
    output        wvalid       ,
    input         wready       ,
    //b           
    input  [3 :0] bid          ,
    input  [1 :0] bresp        ,
    input         bvalid       ,
    output        bready       ,
	output        timer_int_o  ,
	
	//debug
	output wire[`InstAddrBus]           debug_wb_pc1,
	output wire [3:0]                   debug_wb_rf_wen1,
	output wire [4:0]                   debug_wb_rf_wnum1,
	output wire[`RegBus]                debug_wb_rf_wdata1,
	
	output wire[`InstAddrBus]           debug_wb_pc2,
	output wire[3:0]                    debug_wb_rf_wen2,
	output wire[4:0]                    debug_wb_rf_wnum2,
	output wire[`RegBus]                debug_wb_rf_wdata2,
	
	output wire [`RegBus] pref_addr_o
	
);
    
    wire flush;
    
    // cpu to cache
    wire stallreq_from_icache;
    wire icache_valid_i1;  // 从icache取得的第一条指令是否有效
    wire icache_valid_i2;
    wire [`RegBus] icache_addr_i1;  // 从icache返回来的第一条指令的地址
    wire [`RegBus] icache_addr_i2;  // 从icache返回来的第二条指令的地址
    wire [`RegBus] icache_data_i1;  // 从icache取得的第一条指令
    wire [`RegBus] icache_data_i2;  // 从icache取得的第二条指令
    wire [`RegBus] icache_addr_o1;  // 输出到icache的第一条指令的地址
    wire [`RegBus] icache_addr_o2;  // 输出到icache的第二条指令的地址
    wire  icache_req_o;  // icache读请求信号
    wire [2:0] icache_op;
    wire [`RegBus] icache_cdata_o;
   
    wire stallreq_from_dcache;
    wire [`RegBus] dcache_data_i;
    wire [`RegBus] dcache_vaddr_o;
    wire [`RegBus] dcache_data_o;
    wire dcache_wreq_o;
    wire dcache_rreq_o;
    wire [2:0] dcache_arsize_o;
    wire [3:0] dcache_sel_o;
    wire [2:0] dcache_op;
    
    // BPU信息
	wire ex_branch_flag;
	wire predict_success;
	wire [`InstAddrBus] ex_inst_addr_i1;
	wire [`BPBPacketWidth] corr_pkt;
    wire [`BPBPacketWidth] icache_predict_pkt_o1;
    wire [`BPBPacketWidth] icache_predict_pkt_o2;
    wire [`InstAddrBus] icache_npc;
    wire instbuffer_full;    
    
    //cpu
    mycpu cpu(
        .clk              (aclk   ),
        .resetn           (aresetn),  //low active
        .int          (ext_int),  //interrupt,high active
        .timer_int_o   (timer_int_o),
        .flush (flush),
    
//        .stallreq_from_icache(stallreq_from_icache),
        .icache_valid_i1(icache_valid_i1),
        .icache_valid_i2(icache_valid_i2),  // 注意一下
        .icache_addr_i1(icache_addr_i1),
        .icache_addr_i2(icache_addr_i2),   
        .icache_addr_o1(icache_addr_o1),
        .icache_addr_o2(icache_addr_o2),
        .icache_data_i1(icache_data_i1),
        .icache_data_i2(icache_data_i2),
        .icache_req_o(icache_req_o),
        .icache_op(icache_op),
        .icache_cdata_o(icache_cdata_o),
        
        // bpu with icache
        .ex_branch_flag(ex_branch_flag),
	    .predict_success(predict_success),
        .ex_inst_addr_i1(ex_inst_addr_i1),
        .corr_pkt(corr_pkt),
        .instbuffer_full(instbuffer_full),
        .icache_predict_pkt1(icache_predict_pkt_o1),
        .icache_predict_pkt2(icache_predict_pkt_o2),
        .icache_npc(icache_npc),
        
        .stallreq_from_dcache(stallreq_from_dcache),
        .dcache_data_i(dcache_data_i),
        .dcache_addr_o(dcache_vaddr_o),
        .dcache_data_o(dcache_data_o),
        .dcache_wreq_o(dcache_wreq_o),
        .dcache_rreq_o(dcache_rreq_o),
        .dcache_arsize_o(dcache_arsize_o),
        .dcache_sel_o(dcache_sel_o),
        .dcache_op(dcache_op),   
    
        //debug
        .debug_wb_pc1      (debug_wb_pc1      ),
        .debug_wb_rf_wen1  (debug_wb_rf_wen1  ),
        .debug_wb_rf_wnum1 (debug_wb_rf_wnum1 ),
        .debug_wb_rf_wdata1(debug_wb_rf_wdata1),
        .debug_wb_pc2      (debug_wb_pc2      ),
        .debug_wb_rf_wen2  (debug_wb_rf_wen2  ),
        .debug_wb_rf_wnum2 (debug_wb_rf_wnum2 ),
        .debug_wb_rf_wdata2(debug_wb_rf_wdata2),
        .pref_addr_o(pref_addr_o)
    );
    
    wire [`RegBus] dcache_paddr_o;
    wire duncache;
    wire [`RegBus] icache_paddr_o;
    
    va2pa d_va2pa(
        .virtual_addr_i(dcache_vaddr_o),
        .physical_addr_o(dcache_paddr_o),
        .uncached(duncache)
    );
    va2pa i_va2pa(
        .virtual_addr_i(icache_addr_o1),
        .physical_addr_o(icache_paddr_o),
        .uncached(iuncache)
    );        
    
    // icache
    wire iuncache_2;
    wire [7:0] ird_len;
    wire ird_req;
    wire [`RegBus] ird_addr;
    wire ird_valid;
    wire [255:0] ird_data;

    // dcache
    // read
    wire duncache_2;
    wire [7:0] drd_len;
    wire drd_req;
    wire [`RegBus] drd_addr;
    wire drd_valid;
    wire [2:0] drd_arsize;
    wire [255:0] drd_data;
    
    // write
    wire [1:0] judge;
    wire [7:0] dwr_len;
    wire dwr_req;
    wire [31:0] dwr_addr;
    wire [255:0] dwr_data;
    wire [3:0] dwr_wstrb;
    
    wire [7:0] axi_wr_len;
    wire axi_wr_req;
    wire [31:0] axi_wr_addr;
    wire [255:0] axi_wr_data;
    wire [3:0] axi_wr_wstrb;
    
    ICache_pipeline_34way8bank u_ICache_pipeline(
        .clk(aclk),
        .rst(aresetn),
//        .iuncache_i(1'b0),
        .iuncache_i(iuncache),
        .stall(stallreq_from_icache),
        .flush(flush),
        
        //Cache port with CPU
        .valid(icache_req_o),
        .vaddr_i1(icache_addr_o1),
        .vaddr_i2(icache_addr_o2),
        .paddr_i(icache_paddr_o),          
        .data_ok1(icache_valid_i1),         //data transfer out is OK
        .data_ok2(icache_valid_i2),
        .rdata1(icache_data_i1),    
        .rdata2(icache_data_i2),
        .raddr1(icache_addr_i1),
        .raddr2(icache_addr_i2),
        
        // with BPU
        .ex_branch_flag(ex_branch_flag),
	    .predict_success(predict_success),
        .ex_inst_addr_i1(ex_inst_addr_i1),
        .corr_pkt(corr_pkt),
        .instbuffer_full(instbuffer_full),
        .predict_pkto1(icache_predict_pkt_o1),
        .predict_pkto2(icache_predict_pkt_o2),
        .icache_npc(icache_npc),
        
        //Cache port with AXI
        .iuncache_s2(iuncache_2),
        .rd_len(ird_len),
        .rd_req(ird_req),          //read valid request
        .rd_addr(ird_addr),  //read initial address
        .ret_valid(ird_valid),       //return data valid
        .ret_data(ird_data)
    );
    
    DCache_pipeline_2way8bank u_Dcache_pipeline(
        .clk(aclk),
        .rst(aresetn),
        .duncache_i(duncache),
//        .duncache_i(1'b1),        
        //Cache port with CPU
        .rvalid_i(dcache_rreq_o),                //valid request
        .arsize_i(dcache_arsize_o),
        .paddr_i(dcache_paddr_o),          
        .wvalid_i(dcache_wreq_o),                //1:write, 0:read
        .wsel_i(dcache_sel_o),            //write enable
        .wdata_i(dcache_data_o),    
        .rdata_o(dcache_data_i),
        .stall_o(stallreq_from_dcache),
        
        //Cache port with AXI
        .rd_len(drd_len),
        .rd_req_o(drd_req),              //read valid request
        .rd_addr_o(drd_addr),     //read initial address
        .rd_arsize_o(drd_arsize),
        .ret_valid_i(drd_valid),            //return data valid
        .ret_data_i(drd_data),
        
        .wr_len(dwr_len),
        .wr_req_o(dwr_req),          //write valid request 
        .wr_addr_o(dwr_addr),
        .wr_data_o(dwr_data),
        .wr_wstrb_o(dwr_wstrb),
        .wr_valid_i(bvalid),
        
        .duncache_2(duncache_2),
        .judge(judge)
    );
    
    // axi: from axi, to axi
    wire [7:0] axi_rd_len;
    wire axi_rd_req;
    wire [2:0] axi_rd_arsize;
    wire [31:0] axi_rd_addr;
    wire [255:0] axi_rd_data;
    wire axi_rd_valid;
    wire [3:0]axi_rd_arid;
    wire [1:0]axi_rd_cnt;
    
    wire fail_flush_i;
    wire fail_flush_d;
    wire fsh;
    
        
    axi_sel u_axi_sel(
        .clk(aclk),
        .resetn(aresetn),
        .flush(flush),
        .fail_flush_inst(fail_flush_i),
        .fail_flush_data(fail_flush_d),
        .fsh(fsh),

        // cache: from cache, to cache
//        .iuncache(1'b0),
        .iuncache(iuncache_2),
        .ird_len(ird_len),
        .ird_req(ird_req),
        .ird_addr(ird_addr),
        .ird_valid(ird_valid),
        .ird_data(ird_data),

        // dcache
        // read
        .duncache(duncache_2),
//        .duncache(1'b1),
        .drd_len(drd_len),
        .drd_req(drd_req),
        .drd_addr(drd_addr),
        .drd_arsize(drd_arsize),
        .drd_valid(drd_valid),
        .drd_data(drd_data),
        
        // write
        .judge(judge),
        .dwr_len(dwr_len),
        .dwr_req(dwr_req),
        .dwr_addr(dwr_addr),
        .dwr_data(dwr_data),
        .dwr_wstrb(dwr_wstrb),
        
        // axi: from axi, to axi
        .axi_rd_len(axi_rd_len),
        .axi_rd_arsize(axi_rd_arsize),
        .axi_rd_req(axi_rd_req),
        .axi_rd_addr(axi_rd_addr),
        .axi_rd_data(axi_rd_data),
        .axi_rd_arid(axi_rd_arid),
        .axi_rd_rid(rid),
        .axi_rd_cnt(axi_rd_cnt),       
        .axi_rd_valid(rlast & rvalid),
        
        .axi_wr_len(axi_wr_len),
        .axi_wr_req(axi_wr_req),
        .axi_wr_addr(axi_wr_addr),
        .axi_wr_data(axi_wr_data),
        .axi_wr_wstrb(axi_wr_wstrb),
        .axi_wr_valid(bvalid)
        
     );
     
     my_axi u_my_axi(
        .clk(aclk),
        .flush(flush),
        .resetn(aresetn),//????
        .fail_flush_i(fail_flush_i),
        .fail_flush_d(fail_flush_d),

        .awid(awid),//?
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awlock(awlock),//?
        .awcache(awcache),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),

        . wid(wid),
        . wdata(wdata),//??assign??
        . wstrb(wstrb),
        . wlast(wlast),
        . wvalid(wvalid),
        . wready(wready),

        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),//?

        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arlock(arlock),
        .arcache(arcache),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),

        .rid(rid),
        .rdata(rdata),//ret_data
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),//ret_valid
        .rready(rready),

        .rd_req(axi_rd_req),
        .rd_addr(axi_rd_addr),
        .rd_len(axi_rd_len),
        .rd_size(axi_rd_arsize),
        .rd_arid(axi_rd_arid),
        .r_cnt(axi_rd_cnt),
        .first_shake_hand(fsh),
        .wr_req(axi_wr_req),
        .wr_addr(axi_wr_addr),
        .wr_data(axi_wr_data),
        .wr_len(axi_wr_len),
        .wr_wstrb(axi_wr_wstrb),
        .ret_data(axi_rd_data)
     );
endmodule
