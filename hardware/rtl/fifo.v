`timescale 1ns/1ps
module fifo
#(  // Parameters
  parameter          DATA_WIDTH                   = 64,
  parameter          INIT                         = "init.mif",
  parameter          ADDR_WIDTH                   = 4,
  parameter          RAM_DEPTH                    = (1 << ADDR_WIDTH),
  parameter          INITIALIZE_FIFO              = "no",
  parameter          TYPE                         = "distributed"
)(  // Ports
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire                                         s_write_req,
  input  wire                                         s_read_req,
  input  wire  [ DATA_WIDTH           -1 : 0 ]        s_write_data,
  output reg   [ DATA_WIDTH           -1 : 0 ]        s_read_data,
  output wire                                         s_read_ready,
  output wire                                         s_write_ready,
  output wire                                         almost_full,
  output wire                                         almost_empty
);

// Port Declarations
// ******************************************************************
// Internal variables
// ******************************************************************
  reg                                         empty;
  reg                                         full;

  reg  [ ADDR_WIDTH              : 0 ]        fifo_count;

  reg  [ ADDR_WIDTH           -1 : 0 ]        wr_pointer; //Write Pointer
  reg  [ ADDR_WIDTH           -1 : 0 ]        rd_pointer; //Read Pointer

  reg _almost_full;
  reg _almost_empty;

  (* ram_style = TYPE *)
  reg     [DATA_WIDTH   -1 : 0 ]    mem[0:RAM_DEPTH-1];
// ******************************************************************
// FIFO Logic
// ******************************************************************
  initial begin
    if (INITIALIZE_FIFO == "yes") begin
      $readmemh(INIT, mem, 0, RAM_DEPTH-1);
    end
  end

  always @ (fifo_count)
  begin : FIFO_STATUS
    empty   = (fifo_count == 0);
    full    = (fifo_count == RAM_DEPTH);
  end

  always @(posedge clk)
  begin
    if (reset)
      _almost_full <= 1'b0;
    else if (s_write_req && !s_read_req && fifo_count == RAM_DEPTH-4)
      _almost_full <= 1'b1;
    else if (~s_write_req && s_read_req && fifo_count == RAM_DEPTH-4)
      _almost_full <= 1'b0;
  end
  assign almost_full = _almost_full;

  always @(posedge clk)
  begin
    if (reset)
      _almost_empty <= 1'b0;
    else if (~s_write_req && s_read_req && fifo_count == 4)
      _almost_empty <= 1'b1;
    else if (s_write_req && ~s_read_req && fifo_count == 4)
      _almost_empty <= 1'b0;
  end
  assign almost_empty = _almost_empty;

  assign s_read_ready = !empty;
  assign s_write_ready = !full;

  always @ (posedge clk)
  begin : FIFO_COUNTER
    if (reset)
      fifo_count <= 0;

    else if (s_write_req && (!s_read_req||s_read_req&&empty) && !full)
      fifo_count <= fifo_count + 1;

    else if (s_read_req && (!s_write_req||s_write_req&&full) && !empty)
      fifo_count <= fifo_count - 1;
  end

  always @ (posedge clk)
  begin : WRITE_PTR
    if (reset) begin
      wr_pointer <= 0;
    end
    else if (s_write_req && !full) begin
      wr_pointer <= wr_pointer + 1;
    end
  end

  always @ (posedge clk)
  begin : READ_PTR
    if (reset) begin
      rd_pointer <= 0;
    end
    else if (s_read_req && !empty) begin
      rd_pointer <= rd_pointer + 1;
    end
  end

  always @ (posedge clk)
  begin : WRITE
    if (s_write_req & !full) begin
      mem[wr_pointer] <= s_write_data;
    end
  end

  always @ (posedge clk)
  begin : READ
    if (reset) begin
      s_read_data <= 0;
    end
    if (s_read_req && !empty) begin
      s_read_data <= mem[rd_pointer];
    end
    else begin
      s_read_data <= s_read_data;
    end
  end

endmodule
