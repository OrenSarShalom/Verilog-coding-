`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 13.5.2023
// Design Name:asynchronous_fifo
// Module Name:
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
// Asynchronous FIFO 
// You can read about this FIFO pricipals at:
// http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module asynchronous_fifo
  #(
    parameter DEPTH = 128,
    parameter WIDTH = 8,
    parameter SAFE_GUARD = 10        // No. of cells left at FIFO ends, 2*(fast_clk/slow_clk),  min. 2 cells 
    )
   (
    input logic rd_clk,
    input logic wr_clk,
    input logic asynchronous_rst_n,
    input logic [WIDTH-1:0] data_in,
    input logic rd_en,
    input logic wr_en,
    output logic [WIDTH-1:0] data_out,
    output logic fifo_going_full,
    output logic fifo_full,
    output logic fifo_going_empty,
    output logic fifo_empty,
    output logic [$clog2(DEPTH):0] fifo_count
    );

    logic [WIDTH-1:0] fifo [DEPTH-1:0];
    logic [clog2(DEPTH):0] wr_ptr, wr_ptr_on_rd_clk_gray, wr_ptr_on_rd_clk;
    logic [clog2(DEPTH):0] rd_ptr, rd_ptr_on_wr_clk_gray, rd_ptr_on_wr_clk;
    logic [clog2(DEPTH)-1:0] wr_ptr_w, rd_ptr_r;

    logic [clog2(DEPTH):0]  wr_ptr_gray [2:0];
    logic [clog2(DEPTH):0]  rd_ptr_gray [2:0];

    logic asynchronous_rst_n, asynchronous_rst_n_delay, async_rst_n;
    logic wr_rst_n, wr_pre_rst_n;
    logic rd_rst_n, rd_pre_rst_n;
    
    assign rd_ptr_r = rd_ptr[$clog(DEPTH)-1:0];
    assign wr_ptr_w = wr_ptr[$clog(DEPTH)-1:0];

  // Avoids from Asynchronous rst glitches 
   assign asynchronous_rst_n_delay =  asynchronous_rst_n;
   assign async_rst_n = ~(~asynchronous_rst_n & ~asynchronous_rst_n_delay)


 // solve metastability @ Async. rst removal phase - for wr_clk
   always_ff @(posedge wr_clk or negedge async_rst_n)
   if (! async_rst_n) {wr_rst_n, wr_pre_rst_n} <= '0;
   else {wr_rst_n, wr_pre_rst_n} <= {wr_pre_rst_n, 1'b1};


 // solve metastability @ Async. rst removal phase - for rd_clk
   always_ff @(posedge rd_clk or negedge async_rst_n)
      if (! async_rst_n) {rd_rst_n, rd_pre_rst_n} <= '0;
      else {rd_rst_n, rd_pre_rst_n} <= {rd_pre_rst_n, 1'b1};

  
// wr_ptr logic
   always_ff @(posedge rd_clk or negedge rd_rst_n)
       if (! rd_rst_n) rd_ptr <= '0;
       else if rd_en && (!fifo_empty)
               rd_ptr <= rd_ptr + 'd1;
        
//rd_ptr logic 
   always_ff @(posedge wr_clk or negedge wr_rst_n)
       if (! wr_rst_n) wr_ptr <= '0;
       else if wr_en && (!fifo_full) begin
               fifo[wr_ptr_w] <= data_in;
               wr_ptr <= wr_ptr + 'd1;
            end

//////////////////////////// rd_ptr to wr_clk Synchronization ///////////////////////////////////////
  bin2gray 
       #(
       .WIDTH(clog2(DEPTH))
       )
  rd_bin2gray
   (
    .binary_in(rd_ptr),         //  rd_ptr binary value input
    .gray_out(rd_ptr_gray[0])   //  rd_ptr gray value out 
    );     


   always_ff @(posedge wr_clk or negedge wr_rst_n)
   if (!wr_rst_n) {rd_ptr_on_wr_clk_gray, rd_ptr_gray[2:1]} <= '0;
   else begin
          rd_ptr_gray[2:1] <= rd_ptr_gray[1:0];
          rd_ptr_on_wr_clk_gray <= rd_ptr_gray[2]; 
   end

  gray2bin 
       #(
       .WIDTH(clog2(DEPTH))
       )
  wr_gray2bin
   (
    .gray_in(rd_ptr_on_wr_clk_gray),  //  gray value of rd_ptr sync to wr_clk
    .binary_out(rd_ptr_on_wr_clk)     //  binary value out 
    );     

///////////////////////////////////////////////////////////////////////////////////////////////


//////////////////////////// wr_ptr to rd_clk Synchronization //////////////////////////////
  bin2gray 
       #(
       .WIDTH(clog2(DEPTH))
       )
  wr_bin2gray
   (
    .binary_in(wr_ptr),         //  wr_ptr binary value input
    .gray_out(wr_ptr_gray[0])   //  wr_ptr gray value out 
    );     


   always_ff @(posedge rd_clk or negedge rd_rst_n)
   if (!rd_rst_n) {wr_ptr_on_rd_clk_gray, wr_ptr_gray[2:1]} <= '0;
   else begin
          wr_ptr_gray[2:1] <= wr_ptr_gray[1:0];
          wr_ptr_on_rd_clk_gray <= wr_ptr_gray[2]; 
   end

  gray2bin 
       #(
       .WIDTH(clog2(DEPTH))
       )
  rd_gray2bin
   (
    .gray_in(wr_ptr_on_rd_clk_gray),  //  gray value of wr_ptr sync to rd_clk
    .binary_out(wr_ptr_on_rd_clk)     //  binary value out 
    );     

////////////////////////////////////////////////////////////////////////////////////////////////////


    assign fifo_going_empty = (wr_ptr_on_rd_clk - rd_ptr) <= SAFE_GUARD ? 1'b1 : 1'b0;
    assign fifo_empty = (wr_ptr_on_rd_clk == rd_ptr);
    

    assign fifo_going_full = ((wr_ptr - rd_ptr_on_wr_clk) >= (DEPTH - SAFE_GUARD)) ? 1'b1 : 1'b0;
    assign fifo_full = (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr_on_wr_clk[$clog2(DEPTH)-1:0]) 
                        && (wr_ptr[$clog2(DEPTH)] ^ rd_ptr_on_wr_clk[$clog2(DEPTH)]);
    
    assign fifo_count = (wr_ptr_on_rd_clk - rd_ptr);

    assign data_out = fifo[rd_ptr_r];

endmodule