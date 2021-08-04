`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/13 19:10:17
// Design Name: 
// Module Name: my_axi
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
`define AXI_IDLE 3'b000
`define ARREADY 3'b001
`define RVALID 3'b010
`define AWREADY 3'b001
`define WREADY 3'b010
`define BVALID 3'b011

module my_axi(
    input clk,
    input flush,
    input resetn,//????
    output reg fail_flush_i,
    output reg fail_flush_d,
    //axi signals
    //aw
    output [3:0] awid,//?
    output reg [31:0] awaddr,
    output reg [7:0] awlen,
    output reg [2:0] awsize,
    output reg [1:0] awburst,  //01
    output [1:0] awlock,//?
    output reg [3:0] awcache,
    output [2:0] awprot,
    output reg awvalid,
    input  awready,
    
    //w
    output [3:0] wid,
    output reg [31:0] wdata,//??assign??
    output reg [3:0] wstrb,  // 1111
    output reg wlast,
    output reg wvalid,
    input wready,
    
    //b
    input [3:0] bid,
    input [1:0] bresp,
    input bvalid,
    output reg bready,//?
    
    //ar
    output [3:0] arid,
    output [31:0] araddr,
    output [7:0] arlen,
    output [2:0] arsize,
    output reg [1:0] arburst,
    output [1:0] arlock,
    output reg [3:0] arcache,
    output [2:0] arprot,
    output  arvalid,
    input arready,
    
    //r
    input [3:0] rid,
    input [31:0] rdata,//ret_data
    input [1:0] rresp,
    input rlast,
    input rvalid,//ret_valid
//    output reg r4finish,
    output rready,
    
    //cache signals
    input rd_req,
    input [31:0]rd_addr,
    input [7:0]rd_len,
    input [2:0]rd_size,
    input [3:0]rd_arid,
    input wr_req,
    input [31:0]wr_addr,
    input [255:0] wr_data,
    input [7:0]wr_len,
    input [3:0]wr_wstrb,
    output [255:0] ret_data,
    output reg [1:0] r_cnt,
    output first_shake_hand

    );

    
    wire cache_ce;
    assign cache_ce = wr_req | rd_req;
   
    reg [2:0] rcurrent_state_i;// state_machine
    reg [2:0] rcurrent_state_d;
    reg [2:0] wcurrent_state;
    
    reg [2:0] rnext_state_i;
    reg [2:0] rnext_state_d;
    reg [2:0] wnext_state;
    reg [255:0] axi_rbuffer_i;
    reg [255:0] axi_rbuffer_d;
    
    reg [255:0] ret_data_i;
    reg [255:0] ret_data_d;
    reg [1:0]axi_r_cnt;
    reg [3:0]axi_w_cnt;
    
    wire rd_valid;
    assign rd_valid = rvalid & rlast;
    reg rd_valid_ff;
    
    always @(posedge clk) begin
        if(~resetn) begin
            rd_valid_ff <= 1'b0;
        end
        else begin
            rd_valid_ff <= rd_valid;
        end
    end
    
    reg rid_ff;
    always @(posedge clk) begin
        if(~resetn) begin
            rid_ff <= 1'b0;
        end
        else begin
            rid_ff <= rid;
        end
    end
    
    
    assign ret_data = (rd_valid_ff & rid_ff == 4'b0000) ? ret_data_i : 
                      (rd_valid_ff & rid_ff == 4'b0001) ? ret_data_d : 256'd0;
    //aw ????
    assign awid = 4'b0000;
    assign awlock = 2'b00;//AXLOCK_NORMAL
    assign awprot = 3'b000;
    //assign awcache = 4'b0000;
//    assign awlen = 8'b1111;
//    assign awsize = 3'b001;
    
    //w????
    assign wid = 4'b0000;
    //assign wlast = cache_wlast;
   // assign wstrb = 4'b0001;
    
    //b????
//    assign bid = 4'b0000;
    
    //ar????
//    assign arid = 4'b0000;
    assign arlock = 2'b00;
    assign arprot = 3'b000;

    //assign arcache = 4'b0000;
    
    //r???????
    
    //??? 
    always @(posedge clk) begin
        if(resetn == `RstEnable) begin
            rcurrent_state_i <= `AXI_IDLE;
            rcurrent_state_d <= `AXI_IDLE;
            wcurrent_state <= `AXI_IDLE;
        end
        else begin
            rcurrent_state_i <= rnext_state_i;
            rcurrent_state_d <= rnext_state_d;
            wcurrent_state <= wnext_state;
        end
    end
    
    reg fail_flush_ff;
    
    reg aw_flag;
    reg w_flag;
    reg w_flag_state;
    
    reg r_state_i_ff;
    reg r_state_d_ff;
    wire i_finish = r_state_i_ff & ~rcurrent_state_i[1];
    wire d_finish = r_state_d_ff & ~rcurrent_state_d[1];
    
    reg [7:0] arlen_i;
    reg [7:0] arlen_d;
    
    reg [3:0] arsize_i;
    reg [3:0] arsize_d;
    
    reg arvalid_i;
    reg arvalid_d;
    
    reg rready_i;
    reg rready_d;
    
    reg [31:0] araddr_i;
    reg [31:0] araddr_d;
    
    wire can_change_i;
    wire can_change_d;
    
    
    
    assign arid = (arvalid_i & arready) ? 4'b0000: 
                  (arvalid_d & arready) ? 4'b0001: 4'b0000; 
    assign araddr = (arvalid_i & arready) ? araddr_i: 
                  (arvalid_d & arready) ? araddr_d: 32'd0; 
    
    assign arvalid = arvalid_i | arvalid_d;
    assign rready = rready_i | rready_d;
    
    assign arlen = (arvalid_i & arready) ? arlen_i :
                   (arvalid_d & arready) ? arlen_d : 8'b00000000;
                   
    assign arsize = (arvalid_i & arready) ? arsize_i :
                    (arvalid_d & arready) ? arsize_d : 3'b010;
    
    always @(posedge clk)begin
        if(~resetn) begin
            r_state_i_ff <= 1'b0;
        end
        else begin
            r_state_i_ff <= rcurrent_state_i[1];
        end
    end
    
    always @(posedge clk)begin
        if(~resetn) begin
            r_state_d_ff <= 1'b0;
        end
        else begin
            r_state_d_ff <= rcurrent_state_d[1];
        end
    end
    
    assign first_shake_hand = (arvalid & arready);
    
    always @(posedge clk) begin
        if(~resetn) begin
            r_cnt <= 2'b00;
        end
        else if(first_shake_hand & rlast & rvalid) begin
            r_cnt <= r_cnt;
        end
        else if(first_shake_hand) begin
            r_cnt <= r_cnt + 2'b1;
        end 
        else if(rlast & rvalid) begin
            r_cnt <= r_cnt - 2'b1;
        end
    end
            
//    always @(posedge clk) begin
//        if(~resetn)
//            fail_flush_i <= 1'b0;
//        else if(flush & |rcurrent_state_i)
//            fail_flush_i <= 1'b1;
//        else if(~|rcurrent_state_i)
//            fail_flush_i <= 1'b0;
//    end
    
//    always @(posedge clk) begin
//        if(~resetn)
//            fail_flush_d <= 1'b0;
//        else if(flush & |rcurrent_state_d)
//            fail_flush_d <= 1'b1;
//        else if(~|rcurrent_state_d)
//            fail_flush_d <= 1'b0;
//    end
    
    assign can_change_i = (flush & ~(arvalid_i & arready)) & !(rcurrent_state_i == 3'd2) ? 1'b1 : 1'b0;
    assign can_change_d = (flush & ~(arvalid_d & arready)) & !(rcurrent_state_d == 3'd2) ? 1'b1 : 1'b0;
    
    always @(posedge clk) begin
        if(~resetn) begin
            fail_flush_i <= 1'b0;
        end
        else if(rcurrent_state_i == 3'd0) begin
            fail_flush_i <= 1'b0;
        end
        else if(~can_change_i & flush) begin
            fail_flush_i <= 1'b1; 
        end
    end
    
    always @(posedge clk) begin
        if(~resetn) begin
            fail_flush_d <= 1'b0;
        end
        else if(rcurrent_state_d == 3'd0) begin
            fail_flush_d <= 1'b0;
        end
        else if(~can_change_d & flush) begin
            fail_flush_d <= 1'b1; 
        end
    end
    
    
    always @(*)begin
        if(resetn == `RstEnable || can_change_d) begin
            rnext_state_d = `AXI_IDLE;
        end
        else begin
            case(rcurrent_state_d)
            `AXI_IDLE: begin
                if((cache_ce == `True_v && rd_req == `True_v && rd_arid == 4'b0001) && 
                !(rd_addr == awaddr && wnext_state != `AXI_IDLE)) begin
                    rnext_state_d = `ARREADY;
                end
                else begin
                    rnext_state_d = `AXI_IDLE;
                end
            end
            `ARREADY: begin
                if(arready & arvalid_d) begin
                    rnext_state_d = `RVALID;
                end
                else begin
                    rnext_state_d = `ARREADY;
                end
            end
            `RVALID:begin
                if(rlast & rvalid & rid == 4'b0001) begin
                    rnext_state_d = `AXI_IDLE;
                end
                else begin
                    rnext_state_d = `RVALID;
                end
            end
            default:    
                rnext_state_d = `AXI_IDLE;
            endcase
        end
    end
    
    //rcurrent_state_i???(???next_state)
    always @(*) begin
//        if(resetn == `RstEnable || (flush & ~arvalid_i & ~rcurrent_state_i[1])) begin
        if(resetn == `RstEnable || can_change_i) begin
            rnext_state_i = `AXI_IDLE;
        end
        else begin
            case(rcurrent_state_i)
            `AXI_IDLE: begin
                if((cache_ce == `True_v && rd_req == `True_v && rd_arid == 4'b0000) && //?????????????
                !(rd_addr == awaddr && wnext_state != `AXI_IDLE)) begin
                    rnext_state_i = `ARREADY;//????????
                end
                else begin
                    rnext_state_i = `AXI_IDLE;
                end
            end
            `ARREADY: begin
                //if(arready == `True_v && rready == `True_v) begin
                if(arready & arvalid_i) begin
                    rnext_state_i = `RVALID;
                end
                else begin
                    rnext_state_i = `ARREADY;
                end
            end
            `RVALID: begin
                //if(rvalid == `False_v && rready == `False_v) begin
                //if(rready == `False_v) begin
//                if(rlast && rready) begin
                if (rlast && rvalid && rid == 4'b0000) begin
                    rnext_state_i = `AXI_IDLE;
                end
                else begin
                    rnext_state_i = `RVALID;
                  
                end
//                else begin
//                    rnext_state <= `RVALID;
//                end
            end
            default: begin
                rnext_state_i = `AXI_IDLE;
            end
            endcase
        end
    end
    
    reg [2:0] awvalid_cnt;
    
    
    //wnext_state???
    always @(*) begin
        if(resetn == `RstEnable )
            wnext_state = `AXI_IDLE;
        else begin
            case(wcurrent_state)
                `AXI_IDLE: begin
                    if(cache_ce == `True_v && wr_req == `True_v)
                        wnext_state = `AWREADY;
                    else
                        wnext_state = `AXI_IDLE;
                end
                `AWREADY: begin
//                    if(awready & awvalid & wvalid & wready & ~wr_len[1])//32??????????BVALID???
                    if((aw_flag || (awvalid & awready)) & (w_flag_state || (wvalid & wready)) & ~wr_len[1])                    
                        wnext_state = `BVALID;
//                    else if(awready & awvalid & wvalid & wready & wr_len[1])//128???????????wready???????????
                    else if((aw_flag || (awvalid & awready)) & (w_flag_state || (wvalid & wready)) & wr_len[1])
                        wnext_state = `WREADY;
                    else
                        wnext_state = `AWREADY;
                end
                `WREADY: begin
//                    if(~wvalid)
                    if(wlast)
                        wnext_state = `BVALID;
                    else
                        wnext_state = `WREADY;
                end
                `BVALID: begin
                    if(bvalid & bready)
                        wnext_state = `AXI_IDLE;
                    else
                        wnext_state = `BVALID;
                end
                default:    wnext_state = `AXI_IDLE;
            endcase
        end
    end
    //????????assign???
    
   reg wready_flag;
   reg w_finish;
   
    


    reg awvalid_reg;

    always @(posedge clk) begin
        if(resetn ==`RstEnable) begin
            aw_flag <= 1'b0;
        end
        else if(awvalid & awready) begin
            aw_flag <= 1'b1;
        end
        else if(bvalid) begin
            aw_flag <= 1'b0;
        end
    end
    

    always @(posedge clk) begin
        if(resetn == `RstEnable) begin
            w_flag_state <= 1'b0;
        end
        else if(wvalid & wready) begin
            w_flag_state <= 1'b1;
        end
        else if(bvalid) begin
            w_flag_state <= 1'b0;
        end
    end
    
    //??????????output
    always @(posedge clk) begin
        if(resetn == `RstEnable ) begin
            araddr_i <= 32'd0;      
            araddr_d <= 32'd0;      
            arlen_i <= 8'b00000000;     
            arlen_d <= 8'b00000000;     
            arsize_i <= 3'b010;       
            arsize_d <= 3'b010;       
            arburst <= 2'b01;
            arcache <= 4'b0000;
            arvalid_i <= `False_v;
            arvalid_d <= `False_v;
                    
            rready_i <= `False_v;
            rready_d <= `False_v;
            ret_data_i <= 256'd0;
            ret_data_d <= 256'd0;
           // rdata_valid_o <= `False_v;
                    
            awaddr <= 32'd0;       
            awlen <= 8'b00000000;       
            awsize <= 3'b010;      
            awburst <= 2'b01;   
            awcache <= 4'b0000;
            awvalid <= `False_v;
                    
            wvalid <= `False_v;
            wdata <= 32'd0;
            wstrb <= 4'b1111;
            wlast <= `False_v;
            
            bready <= 1'b0;
            
            axi_r_cnt <= 2'b00;
            axi_w_cnt <= 4'b1000;
            axi_rbuffer_i <= 256'd0;
            axi_rbuffer_d <= 256'd0;
        end
        else begin
            case(rcurrent_state_i)
                `AXI_IDLE: begin
                    if(cache_ce == `True_v && rd_req == `True_v && rd_arid == 4'b0000) begin//&& 
                                //!(cache_raddr == awaddr && wnext_state != `AXI_IDLE)) begin
                        araddr_i <= rd_addr;
                        //arlen <= cache_rburst_len;
                        //arlen <= 8'b00000011;
//                        arid <= 4'b0000;
//                        arlen <= rd_len;
                        arlen_i <= rd_len;
//                        arsize <= rd_size;
                        arsize_i <= rd_size;
//                        arsize <= 3'b010;
                        arburst <= 2'b01;
                        arvalid_i <= `False_v;
                        axi_r_cnt <= 2'b00;
                        axi_rbuffer_i <= 256'd0;
//                        bready <= `False_v;
                        ret_data_i <= 256'd0;
                    end
//                    else if(arready) begin
//                        arvalid <= `True_v;
//                    end
                    else begin 
                        ret_data_i <= 256'd0;
                        axi_rbuffer_i <= 256'd0;
                        arvalid_i <= `False_v;
//                        arlen <= 8'b00000000;
                        arlen_i <= 8'b00000000;
                        arsize_i <= 3'b010;
                        //araddr <=
                        //arsize <=
                    end
                end
                `ARREADY: begin
                    if(can_change_i) begin
                        arvalid_i <= `False_v;
                    end
//                    else if(arready) begin//???????????
//                        rready <= `True_v;      
//                        arvalid <= `True_v;
//                    end
                    else if(~arready) begin
                        arvalid_i <= `True_v;
                        rready_i <= `True_v;
                    end
                    else begin
                        arvalid_i <= ~arvalid_i;
                        rready_i <= `True_v;
                    end
                end
                `RVALID: begin
                    //arvalid <= `True_v;
                    arvalid_i <= `False_v;
                    if(rvalid & rlast & ~arlen_i[1] & rid == 4'b0000) begin
                        ret_data_i[255:0] <= {224'b0,rdata};
                        rready_i <= `False_v;
                    end
                    else if(rvalid == `True_v && ~rlast && arlen_i[1] && (rid == 4'b0000)) begin
                        axi_rbuffer_i[255:0] <= {rdata, axi_rbuffer_i[255:32]};
                        //rready <= `False_v;//???????rready???
                        //araddr <= araddr+32'd4;
                        //axi_r_cnt <= axi_r_cnt + 1'b1;
                    end
                    //else if(axi_r_cnt == 2'b11) begin
                    else if(arlen_i[1] && rlast && rvalid && (rid == 4'b0000)) begin
                        ret_data_i[255:0] <= {rdata,axi_rbuffer_i[255:32]};
                        rready_i <= `False_v;
                    end
                    
                end
//                `RVALID:begin
//                    cache_rdata_output[127:0] <= {axi_rbuffer[95:0],rdata};
//                    rready <= `False_v;
//                end
//                default: begin
//                end
            endcase
            
            case(rcurrent_state_d)
                `AXI_IDLE: begin
                    if(cache_ce == `True_v && rd_req == `True_v && rd_arid == 4'b0001) begin
                        araddr_d <= rd_addr;
                        //arlen <= cache_rburst_len;
                        //arlen <= 8'b00000011;
//                        arid <= 4'b0001;
//                        arlen <= rd_len;
                        arlen_d <= rd_len;
//                        arsize <= rd_size;
                        arsize_d <= rd_size;
//                        arsize <= 3'b010;
                        arburst <= 2'b01;
                        arvalid_d <= `False_v;
                        axi_r_cnt <= 2'b00;
                        axi_rbuffer_d <= 256'd0;
//                        bready <= `False_v;
                        ret_data_d <= 256'd0;
                    end
                    else begin
                        ret_data_d <= 256'd0;
                        axi_rbuffer_d <= 256'd0;
                        arvalid_d <= `False_v;
                        arlen_d <= 8'b00000000;
                        arsize_d <= 3'b010;
                    end
                end
                `ARREADY: begin
                    if(can_change_d) begin
                        arvalid_d <= `False_v;
                    end
//                    else if(arready) begin//???????????
//                        rready <= `True_v;      
//                        arvalid <= `True_v;
//                    end
                    else if(~arready) begin
                        arvalid_d <= `True_v;
                        rready_d <= `True_v;
                    end
                    else begin
                        arvalid_d <= ~arvalid_d;
                        rready_d <= `True_v;
                    end
                end
                `RVALID: begin
                    arvalid_d <= `False_v;

                    if(rvalid & rlast & ~arlen_d[1] & rid == 4'b0001) begin
                        ret_data_d[255:0] <= {224'b0,rdata};
                        rready_d <= `False_v;
                    end
                    else if(rvalid == `True_v && ~rlast && arlen_d[1] & rid == 4'b0001) begin
                        axi_rbuffer_d[255:0] <= {rdata, axi_rbuffer_d[255:32]};
                        //rready <= `False_v;//???????rready???
                        //araddr <= araddr+32'd4;
                        //axi_r_cnt <= axi_r_cnt + 1'b1;
                    end
                    //else if(axi_r_cnt == 2'b11) begin
                    else if(arlen_d[1] && rlast && rvalid & rid == 4'b0001) begin
                        ret_data_d[255:0] <= {rdata,axi_rbuffer_d[255:32]};
                        rready_d <= `False_v;
                    end
                end
                default:begin
                end
            endcase
            
            case(wcurrent_state)
                `AXI_IDLE: begin
                    if(cache_ce == `True_v && wr_req == `True_v) begin
                        awaddr <= wr_addr;
                        //awlen <= cache_wburst_len;
                        //awlen <= 8'b00000000;
                        awlen <= wr_len;
                        awvalid_cnt <= wr_len[2:0] +3'b1;
                        //awsize <= cache_wburst_size;
                        awsize <= 3'b010;
                        //awburst <= cache_wburst_type;
                        awburst <= 2'b01;
                        awvalid <= `False_v;
                        bready <= `False_v;
                        wdata <= wr_data[31:0];
                        wvalid <= `False_v;
//                        wdata <= wr_data;
                        axi_w_cnt <= wr_len[3:0] + 4'd1;
                        wready_flag <= 1'b0;
                        w_finish <= 1'b0;
                        wlast <= `False_v;
                        wstrb <= wr_wstrb;
                        awvalid_reg <= 1'b0;
                        
                                           
                    end
                    else begin
                        awvalid <= `False_v;
                        awlen <= 8'b00000000;
                        awsize <= 3'b010;
                        awburst <= 2'b01;
                        bready <= `False_v;
                        awaddr <= 32'd0;
                        wdata <= 32'd0;
                        axi_w_cnt <= 4'b1000;
                        awvalid_cnt <= 3'b0;
                        wready_flag <= 1'b0;
                        wvalid <= `False_v;
                        w_finish <= 1'b0;
                        wlast <= `False_v;
                        wstrb <= 4'b1111;
                        awvalid_reg <= 1'b0;
                    end
                end
                `AWREADY: begin

                    awvalid_reg <= 1'b1;
                    if(~awready) begin
                        awvalid <= `True_v;
                    end
                    else begin
                        awvalid <= ~awvalid;
                    end
                    
                    if(aw_flag) begin
                        awvalid <= `False_v;
                    end
                    wvalid <= `True_v;
                    bready <= `True_v;
                    
                    if(wr_len == 8'b00000000) begin
                        wlast <= `True_v;
                    end
                    if (((wvalid & wready) || w_flag_state) & wr_len == 8'b00000000) begin
                        wvalid <= `False_v;
                    end
                    if(wready && wvalid && ~wr_len[1]) begin//32??????;
                        wdata <= wr_data[31:0];
//                        wlast <= `True_v;
                        w_finish <= 1'b1;
//                        wvalid <= `True_v;
                        //awvalid <= `False_v;
                    end
                    else if(wready && wvalid && wr_len[1] && axi_w_cnt == 4'b1000)begin//128??????
                        wvalid <= `True_v;
                        wdata <= wr_data[63:32];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
                        wready_flag <= 1'b1;
                        //awvalid <= `False_v;
                    end
//                    else if(wready == `True_v && wr_len[1] && axi_w_cnt == 3'b011)begin
//                    else if(wready == `True_v && wr_len[1] && axi_w_cnt == 3'b010)begin
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0111)begin
                        wdata <= wr_data[95:64];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        w_finish <= 1'b1;
                    end
//                    else if(wready == `True_v && wr_len[1] && axi_w_cnt == 3'b001)begin
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0110)begin
                        wdata <= wr_data[127:96];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        w_finish <= 1'b1;
                    end
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0101)begin
                        wdata <= wr_data[159:128];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        w_finish <= 1'b1;
                    end
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0100)begin
                        wdata <= wr_data[191:160];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        w_finish <= 1'b1;
                    end
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0011)begin
                        wdata <= wr_data[223:192];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        w_finish <= 1'b1;
                    end
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0010)begin
                        wdata <= wr_data[255:224];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        wlast <= `True_v;
                        w_finish <= 1'b1;
                    end
                    
                    if(bvalid) begin
                        wvalid <= `False_v;
                    end
                end
                `WREADY: begin
                    awvalid_reg <= 1'b0;

                    if(wready_flag && wr_len[1] && axi_w_cnt == 4'b1000)begin
                        wdata <= wr_data[63:32];
                        axi_w_cnt <= axi_w_cnt - 3'b1;
                    end
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0111)begin
                        wdata <= wr_data[95:64];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        w_finish <= 1'b1;
                    end
//                    else if(wready == `True_v && wr_len[1] && axi_w_cnt == 3'b001)begin
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0110)begin
                        wdata <= wr_data[127:96];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        w_finish <= 1'b1;
                    end
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0101)begin
                        wdata <= wr_data[159:128];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        w_finish <= 1'b1;
                    end
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0100)begin
                        wdata <= wr_data[191:160];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        w_finish <= 1'b1;
                    end
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0011)begin
                        wdata <= wr_data[223:192];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
//                        w_finish <= 1'b1;
                    end
                    else if(wready_flag && wr_len[1] && axi_w_cnt == 4'b0010)begin
                        wdata <= wr_data[255:224];
                        axi_w_cnt <= axi_w_cnt - 4'b1;
                        wlast <= `True_v;
                        w_finish <= 1'b1;
                    end
                    
                    if(axi_w_cnt == 4'd1) begin
                        wvalid <= `False_v;
                    end
                end
                `BVALID: begin
                    awvalid_reg <= 1'b0;


                end
                default: begin
                end
            endcase
        end
    end
    
endmodule
