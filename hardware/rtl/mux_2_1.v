//
// 2:1 Mux
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module mux_2_1 #(
  parameter integer WIDTH     = 8,        // Data Width
  parameter integer IN_WIDTH  = 2*WIDTH,  // Input Width = 2 * Data Width
  parameter integer OUT_WIDTH = WIDTH     // Output Width
) (
  input  wire                                     sel,
  input  wire        [ IN_WIDTH       -1 : 0 ]    data_in,
  output wire        [ OUT_WIDTH      -1 : 0 ]    data_out
);

assign data_out = sel ? data_in[WIDTH+:WIDTH] : data_in[0+:WIDTH];

endmodule
