`timescale 1ns / 1ps
module reg_file #(
    parameter integer  DATA_WIDTH                   = 32,
    parameter integer  ADDR_WIDTH                   = 4
) (
    input  wire                                         clk,
    input  wire                                         rd_req_0,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        rd_addr_0,
    output wire  [ DATA_WIDTH           -1 : 0 ]        rd_data_0,
    input  wire                                         rd_req_1,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        rd_addr_1,
    output wire  [ DATA_WIDTH           -1 : 0 ]        rd_data_1,
    input  wire                                         wr_req_0,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        wr_addr_0,
    input  wire  [ DATA_WIDTH           -1 : 0 ]        wr_data_0
);

//=========================================
// Wires and Regs
//=========================================
    (* ram_style = "distributed" *)
    reg  [ DATA_WIDTH           -1 : 0 ] mem [0 : (1 << ADDR_WIDTH) - 1];
    reg  [ DATA_WIDTH           -1 : 0 ]        rd_data_0_q;
    reg  [ DATA_WIDTH           -1 : 0 ]        rd_data_1_q;
//=========================================


  always @(posedge clk)
  begin
    if (rd_req_0)
      rd_data_0_q <= mem[rd_addr_0];
  end
    assign rd_data_0 = rd_data_0_q;

  always @(posedge clk)
  begin
    if (rd_req_1)
      rd_data_1_q <= mem[rd_addr_1];
  end
    assign rd_data_1 = rd_data_1_q;

  always @(posedge clk)
  begin
    if (wr_req_0)
      mem[wr_addr_0] <= wr_data_0;
  end

endmodule
