`timescale 1ns/1ps
module ram
#(
  parameter integer DATA_WIDTH    = 10,
  parameter integer ADDR_WIDTH    = 12,
  parameter integer OUTPUT_REG    = 0
)
(
  input  wire                         clk,
  input  wire                         reset,

  input  wire                         s_read_req,
  input  wire [ ADDR_WIDTH  -1 : 0 ]  s_read_addr,
  output wire [ DATA_WIDTH  -1 : 0 ]  s_read_data,

  input  wire                         s_write_req,
  input  wire [ ADDR_WIDTH  -1 : 0 ]  s_write_addr,
  input  wire [ DATA_WIDTH  -1 : 0 ]  s_write_data
);

  reg  [ DATA_WIDTH -1 : 0 ] mem [ 0 : 1<<ADDR_WIDTH ];

  always @(posedge clk)
  begin: RAM_WRITE
    if (s_write_req)
      mem[s_write_addr] <= s_write_data;
  end

  generate
    if (OUTPUT_REG == 0)
      assign s_read_data = mem[s_read_addr];
    else begin
      reg [DATA_WIDTH-1:0] _s_read_data;
      always @(posedge clk)
      begin
        if (reset)
          _s_read_data <= 0;
        else if (s_read_req)
          _s_read_data <= mem[s_read_addr];
      end
      assign s_read_data = _s_read_data;
    end
  endgenerate
endmodule
