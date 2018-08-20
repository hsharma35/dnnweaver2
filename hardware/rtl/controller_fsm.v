//
// Loop Controller
//
// (1) RAM to hold loop instructions (max iter count)
// (2) RAM to hold loop states (current iter count)
// (3) FSM that starts when we get the start signal, stops when done
// (4) Stack for the head pointer
//
// Update the loop iterations in controller_fsm when exiting loop
// Update the loop offset in mem-walker-stride when entering loop
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module controller_fsm #(
  parameter integer  LOOP_ID_W                    = 5,
  parameter integer  LOOP_ITER_W                  = 16,
  parameter integer  IMEM_ADDR_W                  = 5,
  // Internal Parameters
  parameter integer  STATE_W                      = 3,
  parameter integer  LOOP_STATE_W                 = LOOP_ID_W,
  parameter integer  STACK_DEPTH                  = (1 << IMEM_ADDR_W)
) (
  input  wire                                         clk,
  input  wire                                         reset,

  // Start and Done handshake signals
  input  wire                                         start,
  output wire                                         done,
  input  wire                                         stall,

  // Loop instruction valid
  input  wire                                         cfg_loop_iter_v,
  input  wire  [ LOOP_ITER_W          -1 : 0 ]        cfg_loop_iter,
  input  wire  [ LOOP_ID_W            -1 : 0 ]        cfg_loop_iter_loop_id,

  output wire  [ LOOP_ID_W            -1 : 0 ]        loop_index,
  output wire                                         loop_index_valid,
  output wire                                         loop_last_iter,
  output wire                                         loop_init,
  output wire                                         loop_enter,
  output wire                                         loop_exit
);


//=============================================================
// Wires/Regs
//=============================================================

  wire                                        loop_wr_req;
  wire [ IMEM_ADDR_W          -1 : 0 ]        loop_wr_ptr;
  wire [ LOOP_ITER_W          -1 : 0 ]        loop_wr_max_iter;

  reg  [ IMEM_ADDR_W          -1 : 0 ]        max_loop_ptr;
  wire [ IMEM_ADDR_W          -1 : 0 ]        loop_rd_ptr;

  wire                                        loop_rd_v;
  wire [ LOOP_ITER_W          -1 : 0 ]        loop_rd_max;

  wire [ IMEM_ADDR_W          -1 : 0 ]        iter_wr_ptr;
  wire                                        iter_wr_v;
  wire [ LOOP_ITER_W          -1 : 0 ]        iter_wr_data;

  reg  [ IMEM_ADDR_W          -1 : 0 ]        loop_index_q;
  reg  [ IMEM_ADDR_W          -1 : 0 ]        loop_index_d; // d -> q

  wire [ IMEM_ADDR_W          -1 : 0 ]        iter_rd_ptr;
  wire                                        iter_rd_v;
  wire [ LOOP_ITER_W          -1 : 0 ]        iter_rd_data;

  reg  [ IMEM_ADDR_W          -1 : 0 ]        stall_rd_ptr;

  wire [ STATE_W              -1 : 0 ]        state;
  reg  [ STATE_W              -1 : 0 ]        state_q;
  reg  [ STATE_W              -1 : 0 ]        state_d;

//=============================================================

//=============================================================
// Loop Instruction Buffer
//=============================================================

  always @(posedge clk)
  begin: MAX_LOOP_PTR
    if (loop_wr_req)
      max_loop_ptr <= cfg_loop_iter_loop_id;
  end

  assign loop_rd_v = iter_rd_v;
  assign loop_rd_ptr = iter_rd_ptr;

  /*
  * This module stores the loop max iterations.
  */
  assign loop_wr_ptr = cfg_loop_iter_loop_id;
  assign loop_wr_req = cfg_loop_iter_v;
  assign loop_wr_max_iter = cfg_loop_iter;
  ram #(
    .ADDR_WIDTH                     ( IMEM_ADDR_W                    ),
    .DATA_WIDTH                     ( LOOP_ITER_W                    )
  ) loop_buf (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .s_write_addr                   ( loop_wr_ptr                    ),
    .s_write_req                    ( loop_wr_req                    ),
    .s_write_data                   ( loop_wr_max_iter               ),
    .s_read_addr                    ( loop_rd_ptr                    ),
    .s_read_req                     ( loop_rd_v                      ),
    .s_read_data                    ( loop_rd_max                    )
  );
//=============================================================

//=============================================================
// Loop Counters
//=============================================================
  /*
  * This module stores the current loop iterations.
  */

  ram #(
    .ADDR_WIDTH                     ( IMEM_ADDR_W                    ),
    .DATA_WIDTH                     ( LOOP_ITER_W                    )
  ) iter_buf (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .s_write_addr                   ( iter_wr_ptr                    ),
    .s_write_req                    ( iter_wr_v                      ),
    .s_write_data                   ( iter_wr_data                   ),
    .s_read_addr                    ( iter_rd_ptr                    ),
    .s_read_req                     ( iter_rd_v                      ),
    .s_read_data                    ( iter_rd_data                   )
  );
//=============================================================

//=============================================================
// FSM
//=============================================================

  localparam integer  IDLE                         = 0;
  localparam integer  INIT_LOOP                    = 1;
  localparam integer  ENTER_LOOP                   = 2;
  localparam integer  INNER_LOOP                   = 3;
  localparam integer  EXIT_LOOP                    = 4;

  always @(*)
  begin
    state_d = state_q;
    loop_index_d = loop_index_q;
    case (state_q)
      IDLE: begin
        loop_index_d = max_loop_ptr;
        if (start) begin
          state_d = INIT_LOOP;
        end
      end
      INIT_LOOP: begin
        if (max_loop_ptr != 0)
          loop_index_d = loop_index_q - 1'b1;
        if (loop_index_q == 1 || loop_index_q == 0)
          state_d = INNER_LOOP;
      end
      ENTER_LOOP: begin
        loop_index_d = loop_index_q - 1'b1;
        if (loop_index_q == 1)
          state_d = INNER_LOOP;
      end
      INNER_LOOP: begin
        if (done)
          state_d = IDLE;
        else if (loop_last_iter && !stall)
        begin
          if (max_loop_ptr != 0) begin
            loop_index_d = loop_index_q + 1'b1;
            state_d = EXIT_LOOP;
          end
          else
            state_d = IDLE;
        end
      end
      EXIT_LOOP: begin
        if (done)
        begin
          loop_index_d = 0;
          state_d = IDLE;
        end
        else if (loop_last_iter)
          loop_index_d = loop_index_q + 1'b1;
        else if (!loop_last_iter)
          state_d = ENTER_LOOP;
      end
      default: begin
        state_d = IDLE;
        loop_index_d = 0;
      end
    endcase
  end

  always @(posedge clk)
  begin
    if (reset)
      loop_index_q <= 'b0;
    else
      loop_index_q <= loop_index_d;
  end

  assign loop_index = loop_index_q;

  always @(posedge clk or posedge reset)
  begin
    if (reset)
      state_q <= 'b0;
    else
      state_q <= state_d;
  end

  assign state = state_q;

//=============================================================

//=============================================================
  // Loop Iteration logic:
  //
  // Set iter counts to zero when initializing the max iters
  // Otherwise, increment write pointer and read pointer every
  // cycle
  //   max_loop_ptr keeps track of the last loop
  //   iter_rd signals correspond to the current iter count
  //   loop_last_iter whenever the current count == max count
//=============================================================
  // assign done = (loop_index == max_loop_ptr) && loop_last_iter;
  assign done = (((state == EXIT_LOOP) && (loop_index == max_loop_ptr)) || ((state == INNER_LOOP) && (max_loop_ptr == 0) && (~stall))) && loop_last_iter;
  assign iter_rd_v = state != IDLE;

  // The below three assign statements update the loop iterations
  assign iter_wr_v = loop_wr_req || state == EXIT_LOOP || (state == INNER_LOOP && !stall);

  assign iter_wr_data = state == IDLE ? 'b0 :
                        loop_last_iter ? 'b0 : iter_rd_data + 1'b1;
  assign iter_wr_ptr = state == IDLE ? cfg_loop_iter_loop_id : loop_index;

  assign loop_last_iter = iter_rd_data == loop_rd_max;

//=============================================================


//=============================================================
// OFFSET generation
//=============================================================

  assign iter_rd_ptr = loop_index;
  assign loop_index_valid = state == INNER_LOOP;

  assign loop_enter = state == ENTER_LOOP || state == INIT_LOOP;
  assign loop_init = state == INIT_LOOP;
  assign loop_exit = state == EXIT_LOOP;

//=============================================================

//=============================================================
// VCD
//=============================================================
`ifdef COCOTB_TOPLEVEL_controller_fsm
initial begin
  $dumpfile("controller_fsm.vcd");
  $dumpvars(0, controller_fsm);
end
`endif
//=============================================================

endmodule
