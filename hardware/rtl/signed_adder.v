//
// Signed Adder
// Implements: out = a + b
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module signed_adder #(
    parameter integer  DTYPE                        = "FXP",
    parameter          REGISTER_OUTPUT              = "FALSE",
    parameter integer  IN1_WIDTH                    = 20,
    parameter integer  IN2_WIDTH                    = 32,
    parameter integer  OUT_WIDTH                    = 32
) (
    input  wire                                         clk,
    input  wire                                         reset,
    input  wire                                         enable,
    input  wire  [ IN1_WIDTH            -1 : 0 ]        a,
    input  wire  [ IN2_WIDTH            -1 : 0 ]        b,
    output wire  [ OUT_WIDTH            -1 : 0 ]        out
  );

  generate
    if (DTYPE == "FXP") begin
      wire signed [ IN1_WIDTH-1:0] _a;
      wire signed [ IN2_WIDTH-1:0] _b;
      wire signed [ OUT_WIDTH-1:0] alu_out;
      assign _a = a;
      assign _b = b;
      assign alu_out = _a + _b;
      if (REGISTER_OUTPUT == "TRUE") begin
        reg [OUT_WIDTH-1:0] _alu_out;
        always @(posedge clk)
        begin
          if (enable)
            _alu_out <= alu_out;
        end
        assign out = _alu_out;
      end else
        assign out = alu_out;
    end
    else if (DTYPE == "FP32") begin
      fp32_add add (
        .clk                            ( clk                            ),
        .a                              ( a                              ),
        .b                              ( b                              ),
        .result                         ( out                            )
        );
    end
    else if (DTYPE == "FP16") begin
      fp_mixed_add add (
        .clk                            ( clk                            ),
        .a                              ( a                              ),
        .b                              ( b                              ),
        .result                         ( out                            )
        );
    end
  endgenerate

endmodule
