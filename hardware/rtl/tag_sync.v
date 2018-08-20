//
// Tag logic for double buffering
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module tag_sync #(
    parameter integer  NUM_TAGS                     = 2,
    parameter integer  TAG_W                        = $clog2(NUM_TAGS),
    parameter integer  STORE_ENABLED                = 1
)
(
    input  wire                                         clk,
    input  wire                                         reset,
    input  wire                                         block_done,
    input  wire                                         tag_req,
    input  wire                                         tag_reuse,
    input  wire                                         tag_bias_prev_sw,
    input  wire                                         tag_ddr_pe_sw,
    output wire                                         tag_ready,
    output wire  [ TAG_W                -1 : 0 ]        tag,
    output wire                                         tag_done,
    input  wire                                         compute_tag_done,
    output wire                                         compute_tag_ready,
    output wire                                         compute_bias_prev_sw,
    output wire  [ TAG_W                -1 : 0 ]        compute_tag,
    input  wire                                         ldmem_tag_done,
    output wire                                         ldmem_tag_ready,
    output wire  [ TAG_W                -1 : 0 ]        ldmem_tag,
    input  wire  [ TAG_W                -1 : 0 ]        raw_stmem_tag,
    output wire                                         raw_stmem_tag_ready,
    output wire                                         stmem_ddr_pe_sw,
    input  wire                                         stmem_tag_done,
    output wire                                         stmem_tag_ready,
    output wire  [ TAG_W                -1 : 0 ]        stmem_tag
);

//==============================================================================
// Wires/Regs
//==============================================================================
    reg  [ TAG_W                -1 : 0 ]        prev_tag;
    reg  [ TAG_W                -1 : 0 ]        tag_alloc;
    reg  [ TAG_W                -1 : 0 ]        ldmem_tag_alloc;
    reg  [ TAG_W                -1 : 0 ]        compute_tag_alloc;
    reg  [ TAG_W                -1 : 0 ]        stmem_tag_alloc;
    reg  [ 2                    -1 : 0 ]        tag0_state_d;
    reg  [ 2                    -1 : 0 ]        tag0_state_q;
    reg  [ 2                    -1 : 0 ]        tag1_state_d;
    reg  [ 2                    -1 : 0 ]        tag1_state_q;

    wire next_compute_tag;

    wire [ NUM_TAGS             -1 : 0 ]        local_next_compute_tag;
    wire [ NUM_TAGS             -1 : 0 ]        local_tag_ready;
    wire [ NUM_TAGS             -1 : 0 ]        local_compute_tag_ready;
//    wire [ NUM_TAGS             -1 : 0 ]        local_compute_tag_reuse;
    wire [ NUM_TAGS             -1 : 0 ]        local_bias_prev_sw;
    wire [ NUM_TAGS             -1 : 0 ]        local_stmem_ddr_pe_sw;
    wire [ NUM_TAGS             -1 : 0 ]        local_ldmem_tag_ready;
    wire [ NUM_TAGS             -1 : 0 ]        local_stmem_tag_ready;

    localparam integer  TAG_FREE                     = 0;
    localparam integer  TAG_LDMEM                    = 1;
    localparam integer  TAG_COMPUTE                  = 2;
    localparam integer  TAG_STMEM                    = 3;

//    wire                                        compute_tag_reuse;

    wire                                        cache_hit;
    wire                                        cache_flush;
//==============================================================================

//==============================================================================
// Tag allocation
//==============================================================================

    assign cache_hit = tag_reuse;
    assign cache_flush = (tag_req && ~tag_reuse) || block_done;

  always @(posedge clk)
  begin
    if (reset)
      tag_alloc <= 'b0;
    else if (tag_req && tag_ready && ~cache_hit) begin
      if (tag_alloc == NUM_TAGS-1)
        tag_alloc <= 'b0;
      else
        tag_alloc <= tag_alloc + 1'b1;
    end
  end
  always @(posedge clk)
  begin
    if (reset)
      prev_tag <= 'b0;
    else if (tag_req && tag_ready && ~cache_hit) begin
      prev_tag <= tag_alloc;
    end
  end

  always @(posedge clk)
  begin
    if (reset)
      ldmem_tag_alloc <= 'b0;
    else if (ldmem_tag_done)
      if (ldmem_tag_alloc == NUM_TAGS-1)
        ldmem_tag_alloc <= 'b0;
      else
        ldmem_tag_alloc <= ldmem_tag_alloc + 1'b1;
  end

  always @(posedge clk)
  begin
    if (reset)
      compute_tag_alloc <= 'b0;
    else if (next_compute_tag)
      if (compute_tag_alloc == NUM_TAGS-1)
        compute_tag_alloc <= 'b0;
      else
        compute_tag_alloc <= compute_tag_alloc + 1'b1;
  end

  always @(posedge clk)
  begin
    if (reset)
      stmem_tag_alloc <= 'b0;
    else if (stmem_tag_done)
      if (stmem_tag_alloc == NUM_TAGS-1)
        stmem_tag_alloc <= 'b0;
      else
        stmem_tag_alloc <= stmem_tag_alloc + 1'b1;
  end

    assign tag_done = &local_tag_ready;

    // Buffer hit/miss logic
    assign tag = tag_reuse ? prev_tag: tag_alloc;
    assign tag_ready = local_tag_ready[prev_tag] || local_tag_ready[tag_alloc];

    assign next_compute_tag = local_next_compute_tag[compute_tag_alloc];

    assign ldmem_tag = ldmem_tag_alloc;
    assign compute_tag = compute_tag_alloc;
    assign stmem_tag = stmem_tag_alloc;

    assign ldmem_tag_ready = local_ldmem_tag_ready[ldmem_tag];
    assign compute_tag_ready = local_compute_tag_ready[compute_tag];
    assign compute_bias_prev_sw = local_bias_prev_sw[compute_tag];
    assign stmem_ddr_pe_sw = local_stmem_ddr_pe_sw[stmem_tag];
    assign stmem_tag_ready = local_stmem_tag_ready[stmem_tag];

    assign raw_stmem_tag_ready = local_stmem_tag_ready[raw_stmem_tag];

//    assign compute_tag_reuse = local_compute_tag_reuse[compute_tag];

  genvar t;
  generate
    for (t=0; t<NUM_TAGS; t=t+1)
    begin: TAG_GEN

    wire                                        _tag_flush;


    wire                                        _next_compute_tag;

    wire                                        _tag_req;
    wire                                        _tag_reuse;
    wire                                        _tag_bias_prev_sw;
    wire                                        _tag_ddr_pe_sw;
    wire                                        _tag_ready;
    wire                                        _tag_done;
    wire                                        _compute_tag_done;
    wire                                        _compute_bias_prev_sw;
    wire                                        _compute_tag_ready;
//    wire                                        _compute_tag_reuse;
    wire                                        _ldmem_tag_done;
    wire                                        _ldmem_tag_ready;
    wire                                        _stmem_tag_done;
    wire                                        _stmem_tag_ready;
    wire                                        _stmem_ddr_pe_sw;

    assign _tag_reuse = tag_reuse && compute_tag_alloc == t;

    assign _tag_req = tag_req && ~tag_reuse && tag_ready && tag == t;
    assign _tag_bias_prev_sw = tag_bias_prev_sw;
    assign _tag_ddr_pe_sw = tag_ddr_pe_sw;
      // assign _tag_done = tag_done && tag == t;
    assign _ldmem_tag_done = ldmem_tag_done && ldmem_tag == t;
    assign _compute_tag_done = compute_tag_done && compute_tag == t;
    assign _stmem_tag_done = stmem_tag_done && stmem_tag == t;

    assign local_tag_ready[t] = _tag_ready;
    assign local_ldmem_tag_ready[t] = _ldmem_tag_ready;
    assign local_compute_tag_ready[t] = _compute_tag_ready;
//    assign local_compute_tag_reuse[t] = _compute_tag_reuse;
    assign local_bias_prev_sw[t] = _compute_bias_prev_sw;
    assign local_stmem_tag_ready[t] = _stmem_tag_ready;
    assign local_stmem_ddr_pe_sw[t] = _stmem_ddr_pe_sw;

    assign local_next_compute_tag[t] = _next_compute_tag;

    assign _tag_flush = cache_flush && prev_tag == t;

      tag_logic local_tag (
    .clk                            ( clk                            ), // input
    .reset                          ( reset                          ), // input
    .next_compute_tag               ( _next_compute_tag              ), // output
    .tag_req                        ( _tag_req                       ), // input
    .tag_reuse                      ( _tag_reuse                     ), // input
    .tag_bias_prev_sw               ( _tag_bias_prev_sw              ), // input
    .tag_ddr_pe_sw                  ( _tag_ddr_pe_sw                 ), // input
    .tag_ready                      ( _tag_ready                     ), // output
    .tag_done                       ( _tag_done                      ), // input
    .tag_flush                      ( _tag_flush                     ), // input
    .compute_tag_done               ( _compute_tag_done              ), // input
//    .compute_tag_reuse              ( _compute_tag_reuse             ), // input
    .compute_bias_prev_sw           ( _compute_bias_prev_sw          ), // output
    .compute_tag_ready              ( _compute_tag_ready             ), // output
    .ldmem_tag_done                 ( _ldmem_tag_done                ), // input
    .ldmem_tag_ready                ( _ldmem_tag_ready               ), // output
    .stmem_ddr_pe_sw                ( _stmem_ddr_pe_sw               ), // output
    .stmem_tag_done                 ( _stmem_tag_done                ), // input
    .stmem_tag_ready                ( _stmem_tag_ready               ) // output
        );

    end
  endgenerate
//==============================================================================

//=============================================================
// VCD
//=============================================================
`ifdef COCOTB_TOPLEVEL_tag_logic
initial begin
  $dumpfile("tag_logic.vcd");
  $dumpvars(0, tag_logic);
end
`endif
//=============================================================
endmodule
