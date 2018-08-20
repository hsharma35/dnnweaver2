//
// Memory Walker - stride
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module mem_walker_stride #(
  // Internal Parameters
  parameter integer  ADDR_WIDTH                   = 48,
  parameter integer  ADDR_STRIDE_W                = 16,
  parameter integer  LOOP_ID_W                    = 5
) (
  input  wire                                         clk,
  input  wire                                         reset,
  // From loop controller
  input  wire  [ ADDR_WIDTH           -1 : 0 ]        base_addr,
  input  wire                                         loop_ctrl_done,
  input  wire  [ LOOP_ID_W            -1 : 0 ]        loop_index,
  input  wire                                         loop_index_valid,
  input  wire                                         loop_init,
  input  wire                                         loop_enter,
  input  wire                                         loop_exit,
  // Address offset - from instruction decoder
  input  wire                                         cfg_addr_stride_v,
  input  wire  [ ADDR_STRIDE_W        -1 : 0 ]        cfg_addr_stride,
  output wire  [ ADDR_WIDTH           -1 : 0 ]        addr_out,
  output wire                                         addr_out_valid
);

//=============================================================
// Wires/Regs
//=============================================================
  reg  [ LOOP_ID_W            -1 : 0 ]        addr_stride_wr_ptr;
  wire                                        addr_stride_wr_req;
  wire [ ADDR_STRIDE_W        -1 : 0 ]        addr_stride_wr_data;

  wire [ LOOP_ID_W            -1 : 0 ]        addr_stride_rd_ptr;
  wire                                        addr_stride_rd_req;
  wire [ ADDR_STRIDE_W        -1 : 0 ]        addr_stride_rd_data;

  wire [ LOOP_ID_W            -1 : 0 ]        addr_offset_wr_ptr;
  wire                                        addr_offset_wr_req;
  wire [ ADDR_WIDTH           -1 : 0 ]        addr_offset_wr_data;

  wire [ LOOP_ID_W            -1 : 0 ]        addr_offset_rd_ptr;
  wire                                        addr_offset_rd_req;
  wire [ ADDR_WIDTH           -1 : 0 ]        addr_offset_rd_data;

  wire [ ADDR_WIDTH           -1 : 0 ]        prev_addr;

  wire [ ADDR_WIDTH           -1 : 0 ]        offset_updated;

  reg  [ ADDR_WIDTH           -1 : 0 ]        _addr_out;
  wire                                        _addr_out_valid;
  
  reg                                         loop_enter_q;

//=============================================================

//=============================================================
// Address stride buffer
//    This module stores the address strides
//=============================================================
  always @(posedge clk)
  begin:WR_PTR
    if (reset)
      addr_stride_wr_ptr <= 'b0;
    else begin
      if (cfg_addr_stride_v)
        addr_stride_wr_ptr <= addr_stride_wr_ptr + 1'b1;
      else if (loop_ctrl_done)
        addr_stride_wr_ptr <= 'b0;
    end
  end

  assign addr_stride_wr_req = cfg_addr_stride_v;
  assign addr_stride_wr_data = cfg_addr_stride;

  assign addr_stride_rd_ptr = loop_index;
  assign addr_stride_rd_req = loop_index_valid || loop_enter;

  ram #(
    .ADDR_WIDTH                     ( LOOP_ID_W                      ),
    .DATA_WIDTH                     ( ADDR_STRIDE_W                  )
  ) stride_buf (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .s_write_addr                   ( addr_stride_wr_ptr             ),
    .s_write_req                    ( addr_stride_wr_req             ),
    .s_write_data                   ( addr_stride_wr_data            ),
    .s_read_addr                    ( addr_stride_rd_ptr             ),
    .s_read_req                     ( addr_stride_rd_req             ),
    .s_read_data                    ( addr_stride_rd_data            )
  );

//=============================================================


//=============================================================
// Offset buffer
//    This module stores the current offset
//=============================================================
  assign addr_offset_wr_ptr = cfg_addr_stride_v ? addr_stride_wr_ptr : loop_index;
  assign addr_offset_wr_req = (cfg_addr_stride_v || loop_enter || loop_index_valid);
  assign addr_offset_wr_data = cfg_addr_stride_v ? 'b0 : offset_updated;
  assign prev_addr = loop_init ? base_addr : (loop_enter && loop_enter_q) ? addr_out : addr_offset_rd_data;
  assign offset_updated = prev_addr + addr_stride_rd_data;

  assign addr_offset_rd_ptr = loop_index;
  assign addr_offset_rd_req = loop_index_valid || loop_enter;

  ram #(
    .ADDR_WIDTH                     ( LOOP_ID_W                      ),
    .DATA_WIDTH                     ( ADDR_WIDTH                     )
  ) offset_buf (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .s_write_addr                   ( addr_offset_wr_ptr             ),
    .s_write_req                    ( addr_offset_wr_req             ),
    .s_write_data                   ( addr_offset_wr_data            ),
    .s_read_addr                    ( addr_offset_rd_ptr             ),
    .s_read_req                     ( addr_offset_rd_req             ),
    .s_read_data                    ( addr_offset_rd_data            )
  );

//=============================================================


//=============================================================
// Output address stride logic
//=============================================================

  assign _addr_out_valid = loop_index_valid;

  always @(posedge clk)
  begin
    if (reset)
      loop_enter_q <= 1'b0;
    else
      loop_enter_q <= loop_enter;
  end

  always @(posedge clk)
  begin
    if (reset)
      _addr_out <= 0;
    else if (loop_init)
      _addr_out <= base_addr;
    else if (loop_enter && !loop_enter_q)
      _addr_out <= addr_offset_rd_data;
    else if (loop_index_valid)
      _addr_out <= _addr_out + addr_stride_rd_data;
  end

  assign addr_out_valid = _addr_out_valid;
  assign addr_out = _addr_out;
//=============================================================



//=============================================================
// VCD
//=============================================================
`ifdef COCOTB_TOPLEVEL_mem_walker_stride
initial begin
  $dumpfile("mem_walker_stride.vcd");
  $dumpvars(0, mem_walker_stride);
end
`endif
//=============================================================

endmodule
