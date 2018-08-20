`timescale 1ns/1ps
module fifo_asymmetric
#(  // Parameters
    parameter integer  WR_DATA_WIDTH                = 64,
    parameter integer  RD_DATA_WIDTH                = 64,
    parameter integer  WR_ADDR_WIDTH                = 4,
    parameter integer  RD_ADDR_WIDTH                = 4
)(  // Ports
    input  wire                                         clk,
    input  wire                                         reset,
    input  wire                                         s_write_req,
    input  wire                                         s_read_req,
    input  wire  [ WR_DATA_WIDTH        -1 : 0 ]        s_write_data,
    output wire  [ RD_DATA_WIDTH        -1 : 0 ]        s_read_data,
    output wire                                         s_read_ready,
    output wire                                         s_write_ready,
    output wire                                         almost_full,
    output wire                                         almost_empty
);

    localparam          NUM_FIFO                     = RD_DATA_WIDTH < WR_DATA_WIDTH ? WR_DATA_WIDTH / RD_DATA_WIDTH : RD_DATA_WIDTH / WR_DATA_WIDTH;
    localparam          FIFO_ID_W                    = $clog2(NUM_FIFO);
    localparam          ADDR_WIDTH                   = RD_DATA_WIDTH < WR_DATA_WIDTH ? WR_ADDR_WIDTH : RD_ADDR_WIDTH;

    wire [ NUM_FIFO             -1 : 0 ]        local_s_write_ready;
    wire [ NUM_FIFO             -1 : 0 ]        local_almost_full;
    wire [ NUM_FIFO             -1 : 0 ]        local_s_read_ready;
    wire [ NUM_FIFO             -1 : 0 ]        local_almost_empty;

    wire [ ADDR_WIDTH              : 0 ]        fifo_count;

genvar i;

generate
if (WR_DATA_WIDTH > RD_DATA_WIDTH)
begin: WR_GT_RD


    reg  [ FIFO_ID_W            -1 : 0 ]        rd_ptr;
    reg  [ FIFO_ID_W            -1 : 0 ]        rd_ptr_dly;

    assign fifo_count = FIFO_INST[NUM_FIFO-1].u_fifo.fifo_count;
    assign s_read_ready = local_s_read_ready[rd_ptr];
    assign s_write_ready = &local_s_write_ready;
    assign almost_empty = local_almost_empty[rd_ptr];
    assign almost_full = |local_almost_full;

  always @(posedge clk)
  begin
    if (reset)
      rd_ptr <= 0;
    else if (s_read_req && s_read_ready)
    begin
      if (rd_ptr == NUM_FIFO-1)
        rd_ptr <= 0;
      else
        rd_ptr <= rd_ptr + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (s_read_req && s_read_ready)
      rd_ptr_dly <= rd_ptr;
  end

for (i=0; i<NUM_FIFO; i=i+1)
begin: FIFO_INST
    wire [ RD_DATA_WIDTH        -1 : 0 ]        _s_write_data;
    wire                                        _s_write_req;
    wire                                        _s_write_ready;
    wire                                        _almost_full;

    wire [ RD_DATA_WIDTH        -1 : 0 ]        _s_read_data;
    wire                                        _s_read_req;
    wire                                        _s_read_ready;
    wire                                        _almost_empty;

    assign _s_write_req = s_write_req;
    assign _s_write_data = s_write_data[i*RD_DATA_WIDTH+:RD_DATA_WIDTH];
    assign local_s_write_ready[i] = _s_write_ready;
    assign local_almost_full[i] = _almost_full;

    assign _s_read_req = s_read_req && (rd_ptr == i);
    assign s_read_data = rd_ptr_dly == i ? _s_read_data : 'bz;
    assign local_s_read_ready[i] = _s_read_ready;
    assign local_almost_empty[i] = _almost_empty;

    fifo #(
    .DATA_WIDTH                     ( RD_DATA_WIDTH                  ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                     )
    ) u_fifo (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .s_write_req                    ( _s_write_req                   ), //input
    .s_write_data                   ( _s_write_data                  ), //input
    .s_write_ready                  ( _s_write_ready                 ), //output
    .s_read_req                     ( _s_read_req                    ), //input
    .s_read_ready                   ( _s_read_ready                  ), //output
    .s_read_data                    ( _s_read_data                   ), //output
    .almost_full                    ( _almost_full                   ), //output
    .almost_empty                   ( _almost_empty                  )  //output
    );
end
end
else
begin: RD_GT_WR

    reg  [ FIFO_ID_W            -1 : 0 ]        wr_ptr;
    assign fifo_count = FIFO_INST[0].u_fifo.fifo_count;

  always @(posedge clk)
  begin
    if (reset)
      wr_ptr <= 0;
    else if (s_write_req && s_write_ready)
    begin
      if (wr_ptr == NUM_FIFO-1)
        wr_ptr <= 0;
      else
        wr_ptr <= wr_ptr + 1'b1;
    end
  end

    assign s_read_ready = &local_s_read_ready;
    assign s_write_ready = local_s_write_ready[wr_ptr];
    assign almost_empty = |local_almost_empty;
    assign almost_full = local_almost_full[wr_ptr];

for (i=0; i<NUM_FIFO; i=i+1)
begin: FIFO_INST
    wire [ WR_DATA_WIDTH        -1 : 0 ]        _s_write_data;
    wire                                        _s_write_req;
    wire                                        _s_write_ready;
    wire                                        _almost_full;

    wire [ WR_DATA_WIDTH        -1 : 0 ]        _s_read_data;
    wire                                        _s_read_req;
    wire                                        _s_read_ready;
    wire                                        _almost_empty;

    assign _s_write_req = s_write_req && (wr_ptr == i);
    assign _s_write_data = s_write_data;
    assign local_s_write_ready[i] = _s_write_ready;
    assign local_almost_full[i] = _almost_full;

    assign _s_read_req = s_read_req;
    assign s_read_data[i*WR_DATA_WIDTH+:WR_DATA_WIDTH] = _s_read_data;
    assign local_s_read_ready[i] = _s_read_ready;
    assign local_almost_empty[i] = _almost_empty;

    fifo #(
    .DATA_WIDTH                     ( WR_DATA_WIDTH                  ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                     )
    ) u_fifo (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .s_write_req                    ( _s_write_req                   ), //input
    .s_write_data                   ( _s_write_data                  ), //input
    .s_write_ready                  ( _s_write_ready                 ), //output
    .s_read_req                     ( _s_read_req                    ), //input
    .s_read_ready                   ( _s_read_ready                  ), //output
    .s_read_data                    ( _s_read_data                   ), //output
    .almost_full                    ( _almost_full                   ), //output
    .almost_empty                   ( _almost_empty                  )  //output
    );
end



end
endgenerate

endmodule
