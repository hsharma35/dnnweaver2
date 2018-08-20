`timescale 1ns / 1ps
module gen_pu_ctrl #(
    parameter integer  ADDR_WIDTH                   = 42,
    parameter integer  BUF_TYPE_W                   = 2,
    parameter integer  INST_WIDTH                   = 32,
    parameter integer  DATA_WIDTH                   = 32,
    parameter integer  IMEM_ADDR_WIDTH              = 10, // 1K = 1 BRAM
    parameter integer  IMM_WIDTH                    = 16,
    parameter integer  ADDR_STRIDE_W                = 32,
    parameter integer  FN_WIDTH                     = 3,
    parameter integer  RF_ADDR_WIDTH                = 4,
    parameter integer  OP_CODE_W                    = 4,
    parameter integer  OP_SPEC_W                    = 7,
    parameter integer  LOOP_ID_W                    = 5,
    parameter integer  LOOP_ITER_W                  = IMM_WIDTH
) (
    input  wire                                         clk,
    input  wire                                         reset,

  // DEBUG
    output wire  [ 3                    -1 : 0 ]        pu_ctrl_state,

  // Handshake - program
    input  wire                                         pu_block_start,
    input  wire                                         pu_compute_start,
    output wire                                         pu_compute_ready,

  // Handshake - compute
    output wire                                         done,

  // Buffer instruction write (to PE) interface
  // TODO: connect inst_wr_req
    input  wire                                         inst_wr_req,
    input  wire  [ INST_WIDTH           -1 : 0 ]        inst_wr_data,
    output wire                                         inst_wr_ready,

  // data streamer - loop iterations
    output wire                                         cfg_loop_iter_v,
    output wire  [ IMM_WIDTH            -1 : 0 ]        cfg_loop_iter,
    output wire  [ 3                    -1 : 0 ]        cfg_loop_iter_type,

  // data streamer - address generation
    output wire                                         cfg_loop_stride_v,
    output wire  [ ADDR_STRIDE_W        -1 : 0 ]        cfg_loop_stride,
    output wire  [ 3                    -1 : 0 ]        cfg_loop_stride_type,

  // ddr ld streamer
    output wire                                         cfg_mem_req_v,
    output wire  [ 2                    -1 : 0 ]        cfg_mem_req_type,

    output wire  [ ADDR_WIDTH           -1 : 0 ]        tag_ld0_base_addr,
    output wire  [ ADDR_WIDTH           -1 : 0 ]        tag_ld1_base_addr,
    output wire  [ ADDR_WIDTH           -1 : 0 ]        tag_st_base_addr,

  // data streamer - address generation
    output wire                                         alu_fn_valid,
    output wire  [ FN_WIDTH             -1 : 0 ]        alu_fn,
    output wire  [ RF_ADDR_WIDTH        -1 : 0 ]        alu_in0_addr,
    output wire                                         alu_in1_src,
    output wire  [ RF_ADDR_WIDTH        -1 : 0 ]        alu_in1_addr,
    output wire  [ RF_ADDR_WIDTH        -1 : 0 ]        alu_out_addr,
    output wire  [ IMM_WIDTH            -1 : 0 ]        alu_imm,

  // From controller
    output wire                                         obuf_ld_stream_read_req,
    input  wire                                         obuf_ld_stream_read_ready,
    output wire                                         ddr_ld0_stream_read_req,
    input  wire                                         ddr_ld0_stream_read_ready,
    output wire                                         ddr_ld1_stream_read_req,
    input  wire                                         ddr_ld1_stream_read_ready,
    output wire                                         ddr_st_stream_write_req,
    input  wire                                         ddr_st_stream_write_ready,
    input  wire                                         ddr_st_done
);

//==============================================================================
// Localparams
//==============================================================================
    localparam          BASE_ADDR_PART_W             = IMM_WIDTH + LOOP_ID_W;
    localparam integer  PU_CTRL_IDLE                 = 0;
    localparam integer  PU_CTRL_DECODE               = 1;
    localparam integer  PU_CTRL_COMPUTE_START        = 2;
    localparam integer  PU_BASE_ADDR_CALC            = 3;
    localparam integer  PU_CTRL_COMPUTE_WAIT         = 4;
    localparam integer  PU_CTRL_COMPUTE              = 5;
    localparam integer  PU_CTRL_COMPUTE_DONE         = 6;
    localparam integer  PU_CTRL_DONE                 = 7;

    localparam integer  OP_SETUP                     = 0;
    localparam integer  OP_LDMEM                     = 1;
    localparam integer  OP_STMEM                     = 2;
    localparam integer  OP_RDBUF                     = 3;
    localparam integer  OP_WRBUF                     = 4;
    localparam integer  OP_GENADDR_HI                = 5;
    localparam integer  OP_GENADDR_LO                = 6;
    localparam integer  OP_LOOP                      = 7;
    localparam integer  OP_BLOCK_REPEAT              = 8;
    localparam integer  OP_BASE_ADDR                 = 9;
    localparam integer  OP_PU_BLOCK                  = 10;
    localparam integer  OP_COMPUTE_R                 = 11;
    localparam integer  OP_COMPUTE_I                 = 12;

    localparam          LD_OBUF                      = 0;
    localparam          LD0_DDR                      = 1;
    localparam          LD1_DDR                      = 2;
//==============================================================================

//==============================================================================
// Wires & Regs
//==============================================================================
    reg  [ IMM_WIDTH            -1 : 0 ]        loop_stride_hi;

    wire [ ADDR_WIDTH           -1 : 0 ]        st_addr;
    wire                                        st_addr_valid;

    wire [ ADDR_WIDTH           -1 : 0 ]        ld0_addr;
    wire                                        ld0_addr_valid;
    wire [ ADDR_WIDTH           -1 : 0 ]        ld1_addr;
    wire                                        ld1_addr_valid;

    reg  [ 1                    -1 : 0 ]        stmem_state_d;
    reg  [ 1                    -1 : 0 ]        stmem_state_q;

    reg                                         loop_status_d;
    reg                                         loop_status_q;

    reg  [ ADDR_WIDTH           -1 : 0 ]        tag_ld0_base_addr_d;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tag_ld0_base_addr_q;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tag_ld1_base_addr_d;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tag_ld1_base_addr_q;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tag_st_base_addr_d;
    reg  [ ADDR_WIDTH           -1 : 0 ]        tag_st_base_addr_q;

    wire                                        loop_ctrl_loop_iter_v;
    wire [ IMM_WIDTH            -1 : 0 ]        loop_ctrl_loop_iter;
    wire                                        loop_ctrl_loop_done;
    wire                                        loop_ctrl_loop_init;
    wire                                        loop_ctrl_loop_enter;
    wire                                        loop_ctrl_loop_exit;
    wire [ LOOP_ID_W            -1 : 0 ]        loop_ctrl_loop_index;
    wire                                        loop_ctrl_loop_index_valid;
    wire                                        loop_ctrl_loop_index_step;

    wire                                        loop_ctrl_start;
    wire                                        loop_ctrl_stall;
    reg  [ LOOP_ID_W            -1 : 0 ]        loop_ctrl_loop_id_counter;
    wire                                        st_stride_v;
    wire [ ADDR_STRIDE_W        -1 : 0 ]        st_stride;
    wire                                        ld0_stride_v;
    wire [ ADDR_STRIDE_W        -1 : 0 ]        ld0_stride;
    wire                                        ld1_stride_v;
    wire [ ADDR_STRIDE_W        -1 : 0 ]        ld1_stride;

    wire [ ADDR_WIDTH           -1 : 0 ]        ld0_tensor_base_addr;
    wire [ ADDR_WIDTH           -1 : 0 ]        ld1_tensor_base_addr;
    wire [ ADDR_WIDTH           -1 : 0 ]        st_tensor_base_addr;
    wire                                        cfg_loop_stride_base;

    reg  [ 3                    -1 : 0 ]        pu_ctrl_state_d;
    reg  [ 3                    -1 : 0 ]        pu_ctrl_state_q;
    wire                                        instruction_valid;
    wire                                        pu_block_end;

    wire [ OP_CODE_W            -1 : 0 ]        op_code;
    wire [ OP_SPEC_W            -1 : 0 ]        op_spec;
    wire [ LOOP_ID_W            -1 : 0 ]        loop_id;
    wire [ IMM_WIDTH            -1 : 0 ]        imm;

    wire                                        stall;
    wire                                        _alu_fn_valid;
    wire                                        _obuf_ld_stream_read_req;
    wire                                        _ddr_ld0_stream_read_req;
    wire                                        _ddr_ld1_stream_read_req;
    wire                                        _ddr_st_stream_write_req;
    wire                                        _ddr_st_stream_write_req_dly1;
    wire                                        _ddr_st_stream_write_req_dly2;
    wire                                        _ddr_st_stream_write_req_dly3;

    wire [ IMM_WIDTH            -1 : 0 ]        block_inst_repeat;
    reg  [ IMM_WIDTH            -1 : 0 ]        block_inst_repeat_d;
    reg  [ IMM_WIDTH            -1 : 0 ]        block_inst_repeat_q;
    reg  [ IMM_WIDTH            -1 : 0 ]        repeat_counter_d;
    reg  [ IMM_WIDTH            -1 : 0 ]        repeat_counter_q;

    reg  [ INST_WIDTH           -1 : 0 ]        mem [ 0 : 1<<IMEM_ADDR_WIDTH ];
    reg  [ IMEM_ADDR_WIDTH      -1 : 0 ]        imem_wr_addr;
    reg  [ IMEM_ADDR_WIDTH      -1 : 0 ]        imem_rd_addr;
    reg  [ IMEM_ADDR_WIDTH      -1 : 0 ]        curr_imem_rd_addr;
    wire [ IMEM_ADDR_WIDTH      -1 : 0 ]        next_imem_rd_addr;
    wire                                        imem_wr_req;
    wire                                        imem_rd_req;

    wire [ INST_WIDTH           -1 : 0 ]        imem_wr_data;
    reg  [ INST_WIDTH           -1 : 0 ]        imem_rd_data;

    reg  [ IMEM_ADDR_WIDTH      -1 : 0 ]        last_inst_addr;
    wire                                        last_inst;
//==============================================================================

//==============================================================================
// Repeat logic
//==============================================================================
    assign imem_wr_req = (op_code == OP_COMPUTE_R || op_code == OP_COMPUTE_I) && pu_ctrl_state_q == PU_CTRL_DECODE;

  always @(posedge clk)
  begin
    if (reset) begin
      imem_wr_addr <= 0;
    end
    else if (done)
      imem_wr_addr <= 0;
    else if (imem_wr_req) begin
      imem_wr_addr <= imem_wr_addr + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (reset)
      last_inst_addr <= 0;
    else if (imem_wr_req)
      last_inst_addr <= imem_wr_addr;
  end

  always @(posedge clk)
  begin
    if (reset) begin
      imem_rd_addr <= 0;
    end
    else begin
      if ((pu_ctrl_state_q == PU_CTRL_COMPUTE) && (~stall || (imem_rd_addr == curr_imem_rd_addr)))
        imem_rd_addr <= next_imem_rd_addr;
      else if (pu_ctrl_state_q == PU_CTRL_DONE)
        imem_rd_addr <= 0;
    end
  end

  always @(posedge clk)
  begin
    if (reset)
      curr_imem_rd_addr <= 0;
    else if (imem_rd_req)
      curr_imem_rd_addr <= imem_rd_addr;
  end

    assign next_imem_rd_addr = imem_rd_addr == last_inst_addr ? 0 : imem_rd_addr + 1'b1;
    assign imem_rd_req = (pu_ctrl_state_q == PU_CTRL_DECODE || pu_ctrl_state_q == PU_CTRL_COMPUTE) && ~stall;
    assign last_inst = last_inst_addr == curr_imem_rd_addr;

  always @(posedge clk)
  begin
    if (reset)
      repeat_counter_q <= 0;
    else
      repeat_counter_q <= repeat_counter_d;
  end

  always @(posedge clk)
  begin: RAM_WRITE
    if (imem_wr_req)
      mem[imem_wr_addr] <= imem_wr_data;
  end
    assign imem_wr_data = inst_wr_data;

  always @(posedge clk)
  begin: RAM_READ
    if (imem_rd_req)
      imem_rd_data <= mem[imem_rd_addr];
  end
//==============================================================================

//==============================================================================
// FSM for the controller
//==============================================================================
  always @(posedge clk)
  begin
    if (reset)
      pu_ctrl_state_q <= PU_CTRL_IDLE;
    else
      pu_ctrl_state_q <= pu_ctrl_state_d;
  end
    assign pu_ctrl_state = pu_ctrl_state_q;

  always @(posedge clk)
  begin
    if (reset)
      block_inst_repeat_q <= 0;
    else
      block_inst_repeat_q <= block_inst_repeat_d;
  end

  always @(*)
  begin
    pu_ctrl_state_d = pu_ctrl_state_q;
    repeat_counter_d = repeat_counter_q;
    block_inst_repeat_d = block_inst_repeat_q;
    case (pu_ctrl_state_q)
      PU_CTRL_IDLE: begin
        if (pu_block_start)
          pu_ctrl_state_d = PU_CTRL_DECODE;
      end
      PU_CTRL_DECODE: begin
        if (pu_block_end) begin
          pu_ctrl_state_d = PU_CTRL_COMPUTE_START;
          block_inst_repeat_d = block_inst_repeat;
        end
      end
      PU_CTRL_COMPUTE_START: begin
        // Get base addresses
        repeat_counter_d = block_inst_repeat_q;
        if (stmem_state_q == 0)
          pu_ctrl_state_d = PU_BASE_ADDR_CALC;
      end
      PU_BASE_ADDR_CALC: begin
        if (stmem_state_q == 1) begin
          pu_ctrl_state_d = PU_CTRL_COMPUTE_WAIT;
        end
      end
      PU_CTRL_COMPUTE_WAIT: begin
        if (pu_compute_start)
          pu_ctrl_state_d = PU_CTRL_COMPUTE;
      end
      PU_CTRL_COMPUTE: begin
        if (last_inst && ~stall) begin
          if (repeat_counter_q == 0) begin
            pu_ctrl_state_d = PU_CTRL_COMPUTE_DONE;
          end
          else
            repeat_counter_d = repeat_counter_q - 1'b1;
        end
      end
      PU_CTRL_COMPUTE_DONE: begin
        if (loop_status_q)
          pu_ctrl_state_d = PU_CTRL_DONE;
        else
          pu_ctrl_state_d = PU_CTRL_COMPUTE_START;
      end
      PU_CTRL_DONE: begin
        pu_ctrl_state_d = PU_CTRL_IDLE;
      end
    endcase
  end

  always @(posedge clk)
  begin
    tag_st_base_addr_q <= tag_st_base_addr_d;
  end
    assign tag_st_base_addr = tag_st_base_addr_q;

    assign pu_compute_ready = pu_ctrl_state_q == PU_CTRL_COMPUTE_WAIT;
    assign done = pu_ctrl_state_q == PU_CTRL_DONE;
    assign pu_block_end = op_code == OP_BLOCK_REPEAT;
    assign instruction_valid = pu_ctrl_state_q == PU_CTRL_DECODE;
    assign inst_wr_ready = pu_ctrl_state_q != PU_CTRL_COMPUTE;
//==============================================================================

//==============================================================================
// Decode
//==============================================================================
    assign {op_code, op_spec, loop_id, imm} = inst_wr_data;
    assign cfg_loop_iter_v = instruction_valid && op_code == OP_LOOP;
    assign cfg_loop_iter = imm;
    assign cfg_loop_iter_type = op_spec[2:0];

    assign cfg_loop_stride_v = instruction_valid && op_code == OP_GENADDR_LO;
    assign cfg_loop_stride[IMM_WIDTH-1:0] = imm;
    assign cfg_loop_stride_type = op_spec[2:0];

    assign cfg_mem_req_v = instruction_valid && op_code == OP_LDMEM;
    assign cfg_mem_req_type = op_spec[5:3];

    assign block_inst_repeat = imm;

  always @(posedge clk)
  begin
    if (reset)
      loop_stride_hi <= 0;
    else begin
      if (cfg_loop_stride_v || done)
        loop_stride_hi <= 0;
      else if (op_code == OP_GENADDR_HI && instruction_valid)
        loop_stride_hi <= imm;
    end
  end

    assign cfg_loop_stride[ADDR_STRIDE_W-1:IMM_WIDTH] = loop_stride_hi;
//==============================================================================

//==============================================================================
// Stall logic
//==============================================================================
    assign _alu_fn_valid = pu_ctrl_state_q == PU_CTRL_COMPUTE;
    assign alu_fn_valid = _alu_fn_valid && ~stall;
    assign {alu_in1_src, alu_fn, alu_imm, alu_in0_addr, alu_out_addr} = imem_rd_data;
    assign alu_in1_addr = alu_imm[3:0];

    assign _obuf_ld_stream_read_req = _alu_fn_valid &&
                                     ((alu_in0_addr[3] == 1 &&
                                       alu_in0_addr[2:0] == LD_OBUF) ||
                                       (~alu_in1_src &&
                                         alu_in1_addr[3] == 1 &&
                                         alu_in1_addr[2:0] == LD_OBUF));

    assign _ddr_ld0_stream_read_req = _alu_fn_valid &&
                                     ((alu_in0_addr[3] == 1 &&
                                       alu_in0_addr[2:0] == LD0_DDR) ||
                                       (~alu_in1_src &&
                                         alu_in1_addr[3] == 1 &&
                                         alu_in1_addr[2:0] == LD0_DDR));

    assign _ddr_ld1_stream_read_req = _alu_fn_valid &&
                                     ((alu_in0_addr[3] == 1 &&
                                       alu_in0_addr[2:0] == LD1_DDR) ||
                                       (~alu_in1_src &&
                                         alu_in1_addr[3] == 1 &&
                                         alu_in1_addr[2:0] == LD1_DDR));

    assign _ddr_st_stream_write_req = _alu_fn_valid &&
                                      (alu_out_addr[3] == 1);

    register_sync_with_enable #(1) ddr_st_delay
    (clk, reset, 1'b1, _ddr_st_stream_write_req && ~stall, _ddr_st_stream_write_req_dly1);
    register_sync_with_enable #(1) ddr_st_delay2
    (clk, reset, 1'b1, _ddr_st_stream_write_req_dly1, _ddr_st_stream_write_req_dly2);
    register_sync_with_enable #(1) ddr_st_delay3
    (clk, reset, 1'b1, _ddr_st_stream_write_req_dly2, _ddr_st_stream_write_req_dly3);

    assign ddr_st_stream_write_req = _ddr_st_stream_write_req_dly2;
    assign obuf_ld_stream_read_req = _obuf_ld_stream_read_req && ~stall;
    assign ddr_ld0_stream_read_req = _ddr_ld0_stream_read_req && ~stall;
    assign ddr_ld1_stream_read_req = _ddr_ld1_stream_read_req && ~stall;

    assign stall = (_obuf_ld_stream_read_req && ~obuf_ld_stream_read_ready) ||
                   (_ddr_ld0_stream_read_req && ~ddr_ld0_stream_read_ready) ||
                   (_ddr_ld1_stream_read_req && ~ddr_ld1_stream_read_ready) ||
                   (_ddr_st_stream_write_req && ~ddr_st_stream_write_ready);
//==============================================================================

//==============================================================================
// Base Address
//==============================================================================
    wire                                        base_addr_v;
    wire [ BUF_TYPE_W           -1 : 0 ]        base_addr_id;
    wire [ 2                    -1 : 0 ]        base_addr_part;
    wire [ BASE_ADDR_PART_W     -1 : 0 ]        base_addr;
    wire [ 3                    -1 : 0 ]        buf_id;
    assign base_addr_v = pu_ctrl_state == PU_CTRL_DECODE && (op_code == OP_BASE_ADDR);
    assign base_addr = {loop_id, imm};
    assign base_addr_id = buf_id;
    assign buf_id = op_spec[5:3];
    assign base_addr_part = op_spec[1:0];

genvar i;
generate
for (i=0; i<2; i=i+1)
begin: BASE_ADDR_CFG

    reg  [ BASE_ADDR_PART_W     -1 : 0 ]        part_ld0_base_addr;
    reg  [ BASE_ADDR_PART_W     -1 : 0 ]        part_ld1_base_addr;
    reg  [ BASE_ADDR_PART_W     -1 : 0 ]        part_st_base_addr;

    assign ld0_tensor_base_addr[i*BASE_ADDR_PART_W+:BASE_ADDR_PART_W] = part_ld0_base_addr;
    assign ld1_tensor_base_addr[i*BASE_ADDR_PART_W+:BASE_ADDR_PART_W] = part_ld1_base_addr;
    assign st_tensor_base_addr[i*BASE_ADDR_PART_W+:BASE_ADDR_PART_W]  = part_st_base_addr;

      always @(posedge clk)
        if (reset)
          part_ld0_base_addr <= 0;
        else if (base_addr_v && base_addr_id == 2 && base_addr_part == i)
          part_ld0_base_addr <= base_addr;
        else if (done)
          part_ld0_base_addr <= 0;

      always @(posedge clk)
        if (reset)
          part_ld1_base_addr <= 0;
        else if (base_addr_v && base_addr_id == 3 && base_addr_part == i)
          part_ld1_base_addr <= base_addr;
        else if (done)
          part_ld1_base_addr <= 0;

      always @(posedge clk)
        if (reset)
          part_st_base_addr <= 0;
        else if (base_addr_v && base_addr_id == 1 && base_addr_part == i)
          part_st_base_addr <= base_addr;
        else if (done)
          part_st_base_addr <= 0;

end
endgenerate
//==============================================================================

//==============================================================================
// Controller
//==============================================================================
    assign loop_ctrl_start = pu_ctrl_state_q == PU_CTRL_COMPUTE_START;
    assign loop_ctrl_stall = ~(pu_ctrl_state_q == PU_BASE_ADDR_CALC && stmem_state_q == 0);
    assign loop_ctrl_loop_iter_v = cfg_loop_iter_v && cfg_loop_iter_type == 5
                                   && pu_ctrl_state_q == PU_CTRL_DECODE;
    assign loop_ctrl_loop_iter = cfg_loop_iter;

    assign loop_ctrl_loop_index_step = loop_ctrl_loop_index_valid && ~loop_ctrl_stall;

    assign st_stride_v = cfg_loop_stride_v && cfg_loop_stride_type == 5
                         && pu_ctrl_state_q == PU_CTRL_DECODE;
    assign st_stride = cfg_loop_stride;

    assign ld0_stride_v = cfg_loop_stride_v && cfg_loop_stride_type == 6
                          && pu_ctrl_state_q == PU_CTRL_DECODE;
    assign ld0_stride = cfg_loop_stride;

    assign ld1_stride_v = cfg_loop_stride_v && cfg_loop_stride_type == 7
                         && pu_ctrl_state_q == PU_CTRL_DECODE;
    assign ld1_stride = cfg_loop_stride;

always @(posedge clk)
begin
  if (reset)
    loop_ctrl_loop_id_counter <= 0;
  else begin
    if (pu_ctrl_state_q == 0)
      loop_ctrl_loop_id_counter <= 0;
    else if (loop_ctrl_loop_iter_v)
      loop_ctrl_loop_id_counter <= loop_ctrl_loop_id_counter + 1'b1;
  end
end

  controller_fsm #(
    .LOOP_ID_W                      ( LOOP_ID_W                      ),
    .LOOP_ITER_W                    ( LOOP_ITER_W                    ),
    .IMEM_ADDR_W                    ( LOOP_ID_W                      )
  ) loop_ctrl_st (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .stall                          ( loop_ctrl_stall                ), //input
    .cfg_loop_iter_v                ( loop_ctrl_loop_iter_v          ), //input
    .cfg_loop_iter                  ( loop_ctrl_loop_iter            ), //input
    .cfg_loop_iter_loop_id          ( loop_ctrl_loop_id_counter      ), //input
    .start                          ( loop_ctrl_start                ), //input
    .done                           ( loop_ctrl_loop_done            ), //output
    .loop_init                      ( loop_ctrl_loop_init            ), //output
    .loop_enter                     ( loop_ctrl_loop_enter           ), //output
    .loop_last_iter                 (                                ), //output
    .loop_exit                      ( loop_ctrl_loop_exit            ), //output
    .loop_index                     ( loop_ctrl_loop_index           ), //output
    .loop_index_valid               ( loop_ctrl_loop_index_valid     )  //output
  );

  mem_walker_stride #(
    .ADDR_WIDTH                     ( ADDR_WIDTH                     ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) mws_st (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .base_addr                      ( st_tensor_base_addr            ), //input
    .loop_ctrl_done                 ( loop_ctrl_loop_done            ), //input
    .loop_index                     ( loop_ctrl_loop_index           ), //input
    .loop_index_valid               ( loop_ctrl_loop_index_step      ), //input
    .loop_init                      ( loop_ctrl_loop_init            ), //input
    .loop_enter                     ( loop_ctrl_loop_enter           ), //input
    .loop_exit                      ( loop_ctrl_loop_exit            ), //input
    .cfg_addr_stride_v              ( st_stride_v                    ), //input
    .cfg_addr_stride                ( st_stride                      ), //input
    .addr_out                       ( st_addr                        ), //output
    .addr_out_valid                 ( st_addr_valid                  )  //output
  );

  mem_walker_stride #(
    .ADDR_WIDTH                     ( ADDR_WIDTH                     ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) mws_ld0 (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .base_addr                      ( ld0_tensor_base_addr           ), //input
    .loop_ctrl_done                 ( loop_ctrl_loop_done            ), //input
    .loop_index                     ( loop_ctrl_loop_index           ), //input
    .loop_index_valid               ( loop_ctrl_loop_index_step      ), //input
    .loop_init                      ( loop_ctrl_loop_init            ), //input
    .loop_enter                     ( loop_ctrl_loop_enter           ), //input
    .loop_exit                      ( loop_ctrl_loop_exit            ), //input
    .cfg_addr_stride_v              ( ld0_stride_v                   ), //input
    .cfg_addr_stride                ( ld0_stride                     ), //input
    .addr_out                       ( ld0_addr                       ), //output
    .addr_out_valid                 ( ld0_addr_valid                 )  //output
  );

  mem_walker_stride #(
    .ADDR_WIDTH                     ( ADDR_WIDTH                     ),
    .ADDR_STRIDE_W                  ( ADDR_STRIDE_W                  ),
    .LOOP_ID_W                      ( LOOP_ID_W                      )
  ) mws_ld1 (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .base_addr                      ( ld1_tensor_base_addr           ), //input
    .loop_ctrl_done                 ( loop_ctrl_loop_done            ), //input
    .loop_index                     ( loop_ctrl_loop_index           ), //input
    .loop_index_valid               ( loop_ctrl_loop_index_step      ), //input
    .loop_init                      ( loop_ctrl_loop_init            ), //input
    .loop_enter                     ( loop_ctrl_loop_enter           ), //input
    .loop_exit                      ( loop_ctrl_loop_exit            ), //input
    .cfg_addr_stride_v              ( ld1_stride_v                   ), //input
    .cfg_addr_stride                ( ld1_stride                     ), //input
    .addr_out                       ( ld1_addr                       ), //output
    .addr_out_valid                 ( ld1_addr_valid                 )  //output
  );
//==============================================================================


//==============================================================================
// LD0 and LD1 base addr
//==============================================================================
always @(posedge clk)
begin
  if (reset)
    tag_ld0_base_addr_q <= 0;
  else if (ld0_addr_valid)
    tag_ld0_base_addr_q <= ld0_addr;
end
always @(posedge clk)
begin
  if (reset)
    tag_ld1_base_addr_q <= 0;
  else if (ld1_addr_valid)
    tag_ld1_base_addr_q <= ld1_addr;
end
    assign tag_ld0_base_addr = tag_ld0_base_addr_q;
    assign tag_ld1_base_addr = tag_ld1_base_addr_q;
//==============================================================================

//==============================================================================
// Store control
//==============================================================================
always @(posedge clk)
begin
  if (reset)
    stmem_state_q <= 0;
  else
    stmem_state_q <= stmem_state_d;
end
always @(*)
begin
  stmem_state_d = stmem_state_q;
  tag_st_base_addr_d = tag_st_base_addr_q;
  case (stmem_state_q)
    0: begin
      if (st_addr_valid) begin
        stmem_state_d = 1;
        tag_st_base_addr_d = st_addr;
      end
    end
    1: begin
      if (ddr_st_done)
        stmem_state_d = 0;
    end
  endcase
end

always @(posedge clk)
begin
  if (reset)
    loop_status_q <= 0;
  else
    loop_status_q <= loop_status_d;
end

always @(*)
begin
  loop_status_d = loop_status_q;
  case(loop_status_q)
    0: begin
      if (loop_ctrl_loop_done)
        loop_status_d = 1;
    end
    1: begin
      if (pu_ctrl_state_q == PU_CTRL_DONE)
        loop_status_d = 0;
    end
  endcase
end
//==============================================================================

endmodule
