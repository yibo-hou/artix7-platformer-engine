// Dual-clock RGB565 FIFO between a DDR3/MIG reader and hdmi_720p.
//
// Write side: MIG ui_clk domain, pixels in raster order.
// Read side: HDMI 74.25 MHz pixel clock domain.
module hdmi_pixel_fifo #(
    parameter integer FIFO_DEPTH = 8192,
    parameter integer PROG_EMPTY_THRESHOLD = 2048
) (
    // FIFO reset is synchronized to wr_clk. pixel_reset is independently
    // synchronized to pixel_clk for read-side status logic.
    input  logic        reset,
    input  logic        pixel_reset,

    // MIG/UI clock domain
    input  logic        wr_clk,
    input  logic [15:0] wr_rgb565,
    input  logic        wr_en,
    output logic        full,
    output logic        prog_full,
    output logic [$clog2(FIFO_DEPTH):0] wr_data_count,

    // HDMI pixel clock domain
    input  logic        pixel_clk,
    input  logic        pixel_req,
    output logic [15:0] pixel_rgb565,
    output logic        pixel_valid,
    output logic        empty,
    output logic        prog_empty,
    output logic        underflow,
    output logic        underflow_sticky
);
    logic [15:0] fifo_dout;
    logic        fifo_rd_en;
    logic        wr_rst_busy;
    logic        rd_rst_busy;
    logic [$clog2(FIFO_DEPTH):0] rd_data_count_unused;

    assign fifo_rd_en  = pixel_req && !empty && !rd_rst_busy;
    assign pixel_valid = !empty && !rd_rst_busy;
    assign pixel_rgb565 = pixel_valid ? fifo_dout : 16'h0000;
    assign underflow = pixel_req && !pixel_valid;

    always_ff @(posedge pixel_clk) begin
        if (pixel_reset || rd_rst_busy)
            underflow_sticky <= 1'b0;
        else if (underflow)
            underflow_sticky <= 1'b1;
    end

    xpm_fifo_async #(
        .CASCADE_HEIGHT(0),
        .CDC_SYNC_STAGES(2),
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("block"),
        .FIFO_READ_LATENCY(0),
        .FIFO_WRITE_DEPTH(FIFO_DEPTH),
        .FULL_RESET_VALUE(0),
        .PROG_EMPTY_THRESH(PROG_EMPTY_THRESHOLD),
        .PROG_FULL_THRESH(FIFO_DEPTH - 512),
        .RD_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH) + 1),
        .READ_DATA_WIDTH(16),
        .READ_MODE("fwft"),
        .RELATED_CLOCKS(0),
        .SIM_ASSERT_CHK(1),
        .USE_ADV_FEATURES("0707"),
        .WAKEUP_TIME(0),
        .WRITE_DATA_WIDTH(16),
        .WR_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH) + 1)
    ) pixel_fifo (
        .rst           (reset),
        .wr_clk        (wr_clk),
        .wr_en         (wr_en && !full && !wr_rst_busy),
        .din           (wr_rgb565),
        .full          (full),
        .prog_full     (prog_full),
        .wr_data_count (wr_data_count),
        .wr_rst_busy   (wr_rst_busy),

        .rd_clk        (pixel_clk),
        .rd_en         (fifo_rd_en),
        .dout          (fifo_dout),
        .empty         (empty),
        .prog_empty    (prog_empty),
        .rd_data_count (rd_data_count_unused),
        .rd_rst_busy   (rd_rst_busy),

        .almost_empty  (),
        .almost_full   (),
        .data_valid    (),
        .dbiterr       (),
        .injectdbiterr (1'b0),
        .injectsbiterr (1'b0),
        .overflow      (),
        .sbiterr       (),
        .sleep         (1'b0),
        .underflow     (),
        .wr_ack        ()
    );
endmodule
