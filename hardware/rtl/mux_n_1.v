//
// n:1 Mux
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module mux_n_1 #(
  parameter integer WIDTH     = 8,                // Data Width
  parameter integer LOG2_N    = 7,                // Log_2(Num of inputs)
  parameter integer IN_WIDTH  = (1<<LOG2_N)*WIDTH,// Input Width = 2 * Data Width
  parameter integer OUT_WIDTH = WIDTH,            // Output Width
  parameter integer TOP_MODULE = 1                 // Output Width
) (
  input  wire        [ LOG2_N         -1 : 0 ]    sel,
  input  wire        [ IN_WIDTH       -1 : 0 ]    data_in,
  output wire        [ OUT_WIDTH      -1 : 0 ]    data_out
);

genvar ii, jj;
generate
if (LOG2_N == 0)
begin
  assign data_out = data_in;
end
else if (LOG2_N > 1)
begin
  localparam integer SEL_LOW_WIDTH = LOG2_N-1; // select at lower level has 1 less width
  localparam integer IN_LOW_WIDTH  = IN_WIDTH / 2; // Input at lower level has half width
  localparam integer OUT_LOW_WIDTH = OUT_WIDTH; // Output at lower level has same width

  wire [ SEL_LOW_WIDTH  -1 : 0 ] sel_low;
  wire [ IN_LOW_WIDTH   -1 : 0 ] in_0;
  wire [ IN_LOW_WIDTH   -1 : 0 ] in_1;
  wire [ OUT_LOW_WIDTH  -1 : 0 ] out_0;
  wire [ OUT_LOW_WIDTH  -1 : 0 ] out_1;

  assign sel_low = sel[LOG2_N-2: 0];
  assign in_0 = data_in[0+:IN_LOW_WIDTH];
  assign in_1 = data_in[IN_LOW_WIDTH+:IN_LOW_WIDTH];

  mux_n_1 #(
    .WIDTH          ( WIDTH         ),
    .TOP_MODULE     ( 0             ),
    .LOG2_N         ( SEL_LOW_WIDTH )
  ) mux_0 (
    .sel            ( sel_low       ),
    .data_in        ( in_0          ),
    .data_out       ( out_0         )
  );

  mux_n_1 #(
    .WIDTH          ( WIDTH         ),
    .TOP_MODULE     ( 0             ),
    .LOG2_N         ( SEL_LOW_WIDTH )
  ) mux_1 (
    .sel            ( sel_low       ),
    .data_in        ( in_1          ),
    .data_out       ( out_1         )
  );

  wire sel_curr = sel[LOG2_N-1];
  localparam IN_CURR_WIDTH = 2 * OUT_WIDTH;
  wire [ IN_CURR_WIDTH -1 : 0 ] in_curr = {out_1, out_0};

  mux_2_1 #(
    .WIDTH          ( WIDTH         )
  ) mux_inst_curr (
    .sel            ( sel_curr      ),
    .data_in        ( in_curr       ),
    .data_out       ( data_out      )
  );
end
else
begin
  mux_2_1 #(
    .WIDTH          ( WIDTH         )
  ) mux_inst_curr (
    .sel            ( sel           ),
    .data_in        ( data_in       ),
    .data_out       ( data_out      )
  );
end
endgenerate
//=========================================
// Debugging: COCOTB VCD
//=========================================
`ifdef COCOTB_TOPLEVEL_mux_n_1
if (TOP_MODULE == 1)
begin
  initial begin
    $dumpfile("mux_n_1.vcd");
    $dumpvars(0, mux_n_1);
  end
end
`endif

endmodule
