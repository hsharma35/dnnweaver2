`timescale 1ns / 1ps
module pu_alu #(
    parameter integer  DATA_WIDTH                   = 16,
    parameter integer  ACC_DATA_WIDTH               = 32,
    parameter integer  IMM_WIDTH                    = 16,
    parameter integer  FN_WIDTH                     = 2
) (
    input  wire                                         clk,
    input  wire                                         fn_valid,
    input  wire  [ FN_WIDTH             -1 : 0 ]        fn,
    input  wire  [ IMM_WIDTH            -1 : 0 ]        imm,
    input  wire  [ ACC_DATA_WIDTH       -1 : 0 ]        alu_in0,
    input  wire                                         alu_in1_src,
    input  wire  [ DATA_WIDTH           -1 : 0 ]        alu_in1,
    output wire  [ ACC_DATA_WIDTH       -1 : 0 ]        alu_out
);

    reg  signed [ ACC_DATA_WIDTH           -1 : 0 ]        alu_out_d;
    reg  signed [ ACC_DATA_WIDTH           -1 : 0 ]        alu_out_q;

  // Instruction types
    localparam integer  FN_NOP                       = 0;
    localparam integer  FN_ADD                       = 1;
    localparam integer  FN_SUB                       = 2;
    localparam integer  FN_MUL                       = 3;
    localparam integer  FN_MVHI                      = 4;

    localparam integer  FN_MAX                       = 5;
    localparam integer  FN_MIN                       = 6;

    localparam integer  FN_RSHIFT                    = 7;

    wire signed [ DATA_WIDTH           -1 : 0 ]        _alu_in1;
    wire signed [ DATA_WIDTH           -1 : 0 ]        _alu_in0;

    wire signed[ ACC_DATA_WIDTH           -1 : 0 ]        add_out;
    wire signed[ ACC_DATA_WIDTH           -1 : 0 ]        sub_out;
    wire signed[ ACC_DATA_WIDTH           -1 : 0 ]        mul_out;
    wire signed[ ACC_DATA_WIDTH           -1 : 0 ]        max_out;
    wire signed[ ACC_DATA_WIDTH           -1 : 0 ]        min_out;
    wire signed[ ACC_DATA_WIDTH           -1 : 0 ]        rshift_out;
    wire signed[ ACC_DATA_WIDTH       -1 : 0 ]        _rshift_out;
    wire [ DATA_WIDTH           -1 : 0 ]        mvhi_out;
    wire                                        gt_out;

    wire [ 5                    -1 : 0 ]        shift_amount;

    assign _alu_in1 = alu_in1_src ? imm : alu_in1;
    assign _alu_in0 = alu_in0;
    assign add_out = _alu_in0 + _alu_in1;
    assign sub_out = _alu_in0 - _alu_in1;
    assign mul_out = _alu_in0 * _alu_in1;
    assign gt_out = _alu_in0 > _alu_in1;
    assign max_out = gt_out ? _alu_in0 : _alu_in1;
    assign min_out = ~gt_out ? _alu_in0 : _alu_in1;
    assign mvhi_out = {imm, 16'b0};

    assign shift_amount = _alu_in1;
    assign _rshift_out = $signed(alu_in0) >>> shift_amount;

    wire signed [ DATA_WIDTH           -1 : 0 ]        _max;
    wire signed [ DATA_WIDTH           -1 : 0 ]        _min;
    wire                                        overflow;
    wire                                        sign;

    assign overflow = (_rshift_out > _max) || (_rshift_out < _min);
    assign sign = $signed(alu_in0) < 0;

    assign _max = (1 << (DATA_WIDTH - 1)) - 1;
    assign _min = -(1 << (DATA_WIDTH - 1));

    assign rshift_out = overflow ? sign ? _min : _max : _rshift_out;

  always @(*)
  begin
    case (fn)
      FN_NOP: alu_out_d = alu_in0;
      FN_ADD: alu_out_d = add_out;
      FN_SUB: alu_out_d = sub_out;
      FN_MUL: alu_out_d = mul_out;
      FN_MVHI: alu_out_d = mvhi_out;
      FN_MAX: alu_out_d = max_out;
      FN_MIN: alu_out_d = min_out;
      FN_RSHIFT: alu_out_d = rshift_out;
      default: alu_out_d = 'bx;
    endcase
  end

  always @(posedge clk)
  begin
    if (fn_valid)
      alu_out_q <= alu_out_d;
  end

    assign alu_out = alu_out_q;

endmodule
