//
// DnnWeaver2 controller - decoder
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module decoder #(
    parameter integer  IMEM_ADDR_W                  = 10,
    parameter integer  DDR_ADDR_W                   = 42,
  // Internal
    parameter integer  INST_W                       = 32,
    parameter integer  BUF_TYPE_W                   = 2,
    parameter integer  IMM_WIDTH                    = 16,
    parameter integer  OP_CODE_W                    = 4,
    parameter integer  OP_SPEC_W                    = 7,
    parameter integer  LOOP_ID_W                    = 5,
    parameter integer  LOOP_ITER_W                  = IMM_WIDTH,
    parameter integer  ADDR_STRIDE_W                = 2*IMM_WIDTH,
    parameter integer  MEM_REQ_SIZE_W               = IMM_WIDTH,
    parameter integer  STATE_W                      = 3
) (
    input  wire                                         clk,
    input  wire                                         reset,
  // Instruction memory
    input  wire  [ INST_W               -1 : 0 ]        imem_read_data,
    output wire  [ IMEM_ADDR_W          -1 : 0 ]        imem_read_addr,
    output wire                                         imem_read_req,
  // Handshake
    input  wire                                         start,
    output wire                                         done,
    output wire                                         loop_ctrl_start,
    input  wire                                         loop_ctrl_done,
    input  wire                                         block_done,
    output wire                                         last_block,
  // Loop strides
    output wire                                         cfg_loop_iter_v,
    output wire  [ LOOP_ITER_W          -1 : 0 ]        cfg_loop_iter,
    output wire  [ LOOP_ID_W            -1 : 0 ]        cfg_loop_iter_loop_id,
  // Loop strides
    output wire                                         cfg_loop_stride_v,
    output wire  [ 2                    -1 : 0 ]        cfg_loop_stride_type,
    output wire  [ ADDR_STRIDE_W        -1 : 0 ]        cfg_loop_stride,
    output wire  [ LOOP_ID_W            -1 : 0 ]        cfg_loop_stride_loop_id,
    output wire  [ BUF_TYPE_W           -1 : 0 ]        cfg_loop_stride_id,
  // Mem access
    output wire                                         cfg_mem_req_v,
    output wire  [ MEM_REQ_SIZE_W       -1 : 0 ]        cfg_mem_req_size,
    output wire  [ 2                    -1 : 0 ]        cfg_mem_req_type, // 0: RD, 1:WR
    output wire  [ LOOP_ID_W            -1 : 0 ]        cfg_mem_req_loop_id, // specify which scratchpad
    output wire  [ BUF_TYPE_W           -1 : 0 ]        cfg_mem_req_id, // specify which scratchpad
  // DDR Address
    output wire  [ DDR_ADDR_W           -1 : 0 ]        ibuf_base_addr,
    output wire  [ DDR_ADDR_W           -1 : 0 ]        wbuf_base_addr,
    output wire  [ DDR_ADDR_W           -1 : 0 ]        obuf_base_addr,
    output wire  [ DDR_ADDR_W           -1 : 0 ]        bias_base_addr,
  // Buf access
    output wire                                         cfg_buf_req_v,
    output wire  [ MEM_REQ_SIZE_W       -1 : 0 ]        cfg_buf_req_size,
    output wire                                         cfg_buf_req_type, // 0: RD, 1: WR
    output wire  [ BUF_TYPE_W           -1 : 0 ]        cfg_buf_req_loop_id, // specify which scratchpad
  // PU
    output wire  [ INST_W               -1 : 0 ]        cfg_pu_inst, // instructions for PU
    output wire                                         cfg_pu_inst_v,  // instructions for PU
    output wire                                         pu_block_start 
);

//=============================================================
// Localparams
//=============================================================
    localparam integer  FSM_IDLE                     = 0; // IDLE
    localparam integer  FSM_DECODE                   = 1; // Decode and Configure Block
    localparam integer  FSM_PU_BLOCK                 = 2; // Wait for execution of inst block
    localparam integer  FSM_EXECUTE                  = 3; // Wait for execution of inst block
    localparam integer  FSM_NEXT_BLOCK               = 4; // Check for next block
    localparam integer  FSM_DONE_WAIT                = 5; // Wait to ensure no RAW hazard
    localparam integer  FSM_DONE                     = 6; // Done
    
    localparam integer  OP_SETUP                     = 0;
    localparam integer  OP_LDMEM                     = 1;
    localparam integer  OP_STMEM                     = 2;
    localparam integer  OP_RDBUF                     = 3;
    localparam integer  OP_WRBUF                     = 4;
    localparam integer  OP_GENADDR_HI                = 5;
    localparam integer  OP_GENADDR_LO                = 6;
    localparam integer  OP_LOOP                      = 7;
    localparam integer  OP_BLOCK_END                 = 8;
    localparam integer  OP_BASE_ADDR                 = 9;
    localparam integer  OP_PU_BLOCK_START            = 10;
    localparam integer  OP_COMPUTE_R                 = 11;
    localparam integer  OP_COMPUTE_I                 = 12;

    localparam integer  MEM_LOAD                     = 0;
    localparam integer  MEM_STORE                    = 1;
    localparam integer  BUF_READ                     = 0;
    localparam integer  BUF_WRITE                    = 1;
//=============================================================

//=============================================================
// Wires/Regs
//=============================================================
    reg  [ 7                       : 0 ]        done_wait_d;
    reg  [ 7                       : 0 ]        done_wait_q;
    reg  [ IMM_WIDTH            -1 : 0 ]        loop_stride_hi;


    wire                                        pu_block_end;

    wire [ IMM_WIDTH            -1 : 0 ]        pu_num_instructions;

    reg  [ STATE_W              -1 : 0 ]        state_q;
    reg  [ STATE_W              -1 : 0 ]        state_d;
    wire [ STATE_W              -1 : 0 ]        state;

    wire [ OP_CODE_W            -1 : 0 ]        op_code;
    wire [ OP_SPEC_W            -1 : 0 ]        op_spec;
    wire [ LOOP_ID_W            -1 : 0 ]        loop_level;
    wire [ LOOP_ID_W            -1 : 0 ]        loop_id;
    wire [ IMM_WIDTH            -1 : 0 ]        immediate;

    wire [ BUF_TYPE_W           -1 : 0 ]        buf_id;

    wire                                        inst_valid;
    reg                                         _inst_valid;
    wire                                        block_end;

    reg  [ IMM_WIDTH            -1 : 0 ]        pu_inst_counter_d;
    reg  [ IMM_WIDTH            -1 : 0 ]        pu_inst_counter_q;

    reg  [ IMEM_ADDR_W          -1 : 0 ]        addr_d;
    reg  [ IMEM_ADDR_W          -1 : 0 ]        addr_q;

    wire                                        base_addr_v;
    wire [ BUF_TYPE_W           -1 : 0 ]        base_addr_id;
    wire [ 2                    -1 : 0 ]        base_addr_part;
  wire [ IMM_WIDTH + LOOP_ID_W            -1 : 0 ]        base_addr;
//=============================================================

//=============================================================
// Logic
//=============================================================
  // Ops
    assign loop_ctrl_start = block_end;

    assign imem_read_req = state == FSM_DECODE || state == FSM_PU_BLOCK;
    assign imem_read_addr = addr_q;
  always @(posedge clk)
  begin
    if (reset)
      addr_q <= {IMEM_ADDR_W{1'b0}};
    else
      addr_q <= addr_d;
  end

  // Decode instructions
    assign {op_code, op_spec, loop_id, immediate} = imem_read_data;
    assign buf_id = op_spec[5:3];

    assign block_end = op_code == OP_BLOCK_END && _inst_valid && state == FSM_DECODE;

    assign cfg_loop_iter_v = (op_code == OP_LOOP) && inst_valid;
    assign cfg_loop_iter = immediate;
    assign cfg_loop_iter_loop_id = loop_id;

    assign cfg_loop_stride_v = (op_code == OP_GENADDR_LO) && inst_valid;
    assign cfg_loop_stride[IMM_WIDTH-1:0] = immediate;
    assign cfg_loop_stride_id = buf_id;
    assign cfg_loop_stride_type = op_spec[1:0];
    assign cfg_loop_stride_loop_id = loop_id;

    assign cfg_mem_req_v = (op_code == OP_LDMEM || op_code == OP_STMEM) && inst_valid;
    assign cfg_mem_req_size = immediate;
    assign cfg_mem_req_type = op_code == OP_LDMEM ? MEM_LOAD : MEM_STORE;
    assign cfg_mem_req_loop_id = loop_id;
    assign cfg_mem_req_id = buf_id;

    assign cfg_buf_req_v = (op_code == OP_RDBUF || op_code == OP_WRBUF) && inst_valid;
    assign cfg_buf_req_size = immediate;
    assign cfg_buf_req_type = op_code == OP_RDBUF ? BUF_READ : BUF_WRITE;
    assign cfg_buf_req_loop_id = buf_id;

    assign base_addr_v = (op_code == OP_BASE_ADDR) && inst_valid;
    assign base_addr = {loop_id, immediate};
    assign base_addr_id = buf_id;
    assign base_addr_part = op_spec[1:0];

    assign pu_num_instructions = immediate;
    assign pu_block_start = inst_valid && (op_code == OP_PU_BLOCK_START);
    assign pu_block_end = state == FSM_PU_BLOCK && pu_inst_counter_q == 0;
    assign cfg_pu_inst_v = state == FSM_PU_BLOCK;
    assign cfg_pu_inst = imem_read_data;
//=============================================================

//=============================================================
// FSM
//=============================================================
    reg                                         last_block_d;
    reg                                         last_block_q;
    assign last_block = last_block_q;
always @(posedge clk)
begin
  if (reset)
    last_block_q <= 0;
  else
    last_block_q <= last_block_d;
end

always @(posedge clk)
begin
  if (reset)
    done_wait_q <= 0;
  else
    done_wait_q <= done_wait_d;
end


  always @(*)
  begin: FSM
    state_d = state_q;
    addr_d = addr_q;
    pu_inst_counter_d = pu_inst_counter_q;
    last_block_d = last_block_q;
    done_wait_d = done_wait_q;
    case(state_q)
      FSM_IDLE: begin
        if (start) begin
          state_d = FSM_DECODE;
          addr_d = 0;
        end
      end
      FSM_DECODE: begin
        if (loop_ctrl_start) begin
          state_d = FSM_EXECUTE;
          last_block_d = immediate[0];
        end
        else if (pu_block_start) begin
          state_d = FSM_PU_BLOCK;
          addr_d = addr_q + 1'b1;
          pu_inst_counter_d = pu_num_instructions;
        end
        else
          addr_d = addr_q + 1'b1;
      end
      FSM_PU_BLOCK: begin
        addr_d = addr_q + 1'b1;
        if (pu_block_end) begin
          state_d = FSM_DECODE;
        end
        else begin
          pu_inst_counter_d = pu_inst_counter_q - 1'b1;
        end
      end
      FSM_EXECUTE: begin
        if (block_done) begin
          state_d = FSM_NEXT_BLOCK;
        end
      end
      FSM_NEXT_BLOCK: begin
        if (last_block_q) begin
          done_wait_d = 8'd128;
          state_d = FSM_DONE_WAIT;
        end
        else begin
          state_d = FSM_DECODE;
        end
      end
      FSM_DONE_WAIT: begin
        if (done_wait_d == 8'd0) begin
          state_d = FSM_DONE;
        end
        else
          done_wait_d = done_wait_d - 1'b1;
      end
      FSM_DONE: begin
        state_d = FSM_IDLE;
      end
    endcase
  end

    assign done = state_q == FSM_DONE;

  always @(posedge clk)
  begin
    if (reset)
      _inst_valid <= 1'b0;
    else
      _inst_valid <= imem_read_req;
  end
    assign inst_valid = _inst_valid && !block_end && state == FSM_DECODE;

  always @(posedge clk)
  begin
    if (reset)
      pu_inst_counter_q <= 0;
    else
      pu_inst_counter_q <= pu_inst_counter_d;
  end

  always @(posedge clk)
  begin
    if (reset)
      state_q <= FSM_IDLE;
    else
      state_q <= state_d;
  end

    assign state = state_q;
//=============================================================

//=============================================================
// Base Address
//=============================================================
  genvar i;
  generate
    for (i=0; i<2; i=i+1)
    begin: BASE_ADDR_CFG

    reg  [ 21                   -1 : 0 ]        _obuf_base_addr;
    reg  [ 21                   -1 : 0 ]        _bias_base_addr;
    reg  [ 21                   -1 : 0 ]        _ibuf_base_addr;
    reg  [ 21                   -1 : 0 ]        _wbuf_base_addr;

    assign ibuf_base_addr[i*21+:21] = _ibuf_base_addr;
    assign wbuf_base_addr[i*21+:21] = _wbuf_base_addr;
    assign obuf_base_addr[i*21+:21] = _obuf_base_addr;
    assign bias_base_addr[i*21+:21] = _bias_base_addr;

      always @(posedge clk)
        if (reset)
          _ibuf_base_addr <= 0;
        else if (base_addr_v && base_addr_id == 0 && base_addr_part == i)
          _ibuf_base_addr <= base_addr;
        else if (block_done)
          _ibuf_base_addr <= 0;

      always @(posedge clk)
        if (reset)
          _wbuf_base_addr <= 0;
        else if (base_addr_v && base_addr_id == 2 && base_addr_part == i)
          _wbuf_base_addr <= base_addr;
        else if (block_done)
          _wbuf_base_addr <= 0;

      always @(posedge clk)
        if (reset)
          _obuf_base_addr <= 0;
        else if (base_addr_v && base_addr_id == 1 && base_addr_part == i)
          _obuf_base_addr <= base_addr;
        else if (block_done)
          _obuf_base_addr <= 0;

      always @(posedge clk)
        if (reset)
          _bias_base_addr <= 0;
        else if (base_addr_v && base_addr_id == 3 && base_addr_part == i)
          _bias_base_addr <= base_addr;
        else if (block_done)
          _bias_base_addr <= 0;

    end
  endgenerate

  always @(posedge clk)
  begin
    if (reset)
      loop_stride_hi <= 0;
    else begin
      if (cfg_loop_stride_v || block_done)
        loop_stride_hi <= 0;
      else if (op_code == OP_GENADDR_HI && inst_valid)
        loop_stride_hi <= immediate;
    end
  end

    assign cfg_loop_stride[ADDR_STRIDE_W-1:IMM_WIDTH] = loop_stride_hi;
//=============================================================

//=============================================================
// VCD
//=============================================================
  `ifdef COCOTB_TOPLEVEL_decoder
    initial begin
    $dumpfile("decoder.vcd");
    $dumpvars(0, decoder);
    end
  `endif
//=============================================================

endmodule
