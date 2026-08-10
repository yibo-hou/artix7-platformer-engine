// Bridges an RGB565 AXI4-Stream frame from AXI VDMA MM2S into the asynchronous
// HDMI pixel FIFO. The VDMA side may stop on FIFO backpressure.
//
// The bridge verifies SOF/EOL placement but does not repair a malformed stream.
// Hold hdmi_720p in reset until fifo_prefilled is asserted for the first frame.
module hdmi_vdma_fifo_bridge #(
    parameter integer FIFO_DEPTH = 8192,
    parameter integer PREFILL_PIXELS = 4096
) (
    input  logic        axis_reset,
    input  logic        pixel_reset,

    // AXI VDMA M_AXIS_MM2S clock domain.
    input  logic        axis_clk,
    input  logic [15:0] s_axis_tdata,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    input  logic        s_axis_tuser,
    input  logic        s_axis_tlast,
    input  logic        flush_request,

    // HDMI pixel clock domain.
    input  logic        pixel_clk,
    input  logic        pixel_req,
    output logic [15:0] pixel_rgb565,
    output logic        pixel_valid,

    output logic        fifo_full,
    output logic        fifo_prog_full,
    output logic        fifo_empty,
    output logic        fifo_prog_empty,
    output logic        fifo_prefilled,
    output logic [$clog2(FIFO_DEPTH):0] fifo_wr_data_count,
    output logic        underflow,
    output logic        underflow_sticky,
    output logic        stream_error_sticky
);
    logic [$clog2(FIFO_DEPTH):0] wr_data_count;
    logic [10:0] stream_x;
    logic [9:0]  stream_y;
    logic        stream_fire;
    logic        fifo_prefilled_axis;
    logic        fifo_prefilled_sync;
    logic        flush_request_axis;
    logic        flush_request_axis_d;
    logic        flush_pending;
    logic [4:0]  flush_reset_count;
    logic        fifo_flush_reset;

    assign fifo_flush_reset = flush_reset_count != 0;
    // While seeking SOF, consume and discard non-SOF beats. Stop on the SOF
    // itself so AXI keeps that beat stable across the FIFO reset interval.
    assign s_axis_tready = flush_pending ? !s_axis_tuser :
                           (!fifo_prog_full && !fifo_flush_reset);
    assign stream_fire = s_axis_tvalid && s_axis_tready && !flush_pending;
    assign fifo_wr_data_count = wr_data_count;

    hdmi_pixel_fifo #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .PROG_EMPTY_THRESHOLD(PREFILL_PIXELS / 2)
    ) pixel_fifo (
        .reset            (axis_reset || fifo_flush_reset),
        .pixel_reset      (pixel_reset),
        .wr_clk           (axis_clk),
        .wr_rgb565        (s_axis_tdata),
        .wr_en            (stream_fire),
        .full             (fifo_full),
        .prog_full        (fifo_prog_full),
        .wr_data_count    (wr_data_count),
        .pixel_clk        (pixel_clk),
        .pixel_req        (pixel_req),
        .pixel_rgb565     (pixel_rgb565),
        .pixel_valid      (pixel_valid),
        .empty            (fifo_empty),
        .prog_empty       (fifo_prog_empty),
        .underflow        (underflow),
        .underflow_sticky (underflow_sticky)
    );

    always_ff @(posedge axis_clk) begin
        if (axis_reset || fifo_flush_reset) begin
            stream_x           <= '0;
            stream_y           <= '0;
            stream_error_sticky <= 1'b0;
        end else begin
            if (stream_fire) begin
                if (s_axis_tuser != ((stream_x == 0) && (stream_y == 0)))
                    stream_error_sticky <= 1'b1;

                if (s_axis_tuser) begin
                    stream_x <= '0;
                    stream_y <= '0;
                end

                if (s_axis_tlast != (stream_x == 1279))
                    stream_error_sticky <= 1'b1;

                if (stream_x == 1279) begin
                    stream_x <= '0;
                    if (stream_y == 719)
                        stream_y <= '0;
                    else
                        stream_y <= stream_y + 1'b1;
                end else begin
                    stream_x <= stream_x + 1'b1;
                end
            end
        end
    end

    // On a source change, hold AXI ready low until VDMA presents the next
    // SOF. The SOF beat remains stable while the asynchronous FIFO resets,
    // so it becomes the first accepted pixel after the reset completes.
    xpm_cdc_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (1),
        .SRC_INPUT_REG  (0)
    ) flush_request_cdc (
        .src_clk  (1'b0),
        .src_in   (flush_request),
        .dest_clk (axis_clk),
        .dest_out (flush_request_axis)
    );

    always_ff @(posedge axis_clk) begin
        if (axis_reset) begin
            flush_request_axis_d <= 1'b0;
            flush_pending        <= 1'b0;
            flush_reset_count    <= '0;
            fifo_prefilled_axis  <= 1'b0;
        end else begin
            flush_request_axis_d <= flush_request_axis;

            if (flush_request_axis && !flush_request_axis_d) begin
                flush_pending       <= 1'b1;
                fifo_prefilled_axis <= 1'b0;
            end

            if (flush_pending && s_axis_tvalid && s_axis_tuser) begin
                flush_pending     <= 1'b0;
                flush_reset_count <= 5'd16;
            end else if (flush_reset_count != 0) begin
                flush_reset_count <= flush_reset_count - 1'b1;
            end

            if (!(flush_request_axis && !flush_request_axis_d) &&
                !flush_pending && !fifo_flush_reset &&
                wr_data_count >= PREFILL_PIXELS)
                fifo_prefilled_axis <= 1'b1;
        end
    end

    // Synchronize the startup level indication before it is used to release
    // the HDMI timing generator in the pixel clock domain. XPM supplies the
    // corresponding CDC timing exceptions.
    xpm_cdc_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (1),
        .SRC_INPUT_REG  (0)
    ) prefilled_cdc (
        .src_clk  (1'b0),
        .src_in   (fifo_prefilled_axis),
        .dest_clk (pixel_clk),
        .dest_out (fifo_prefilled_sync)
    );

    always_ff @(posedge pixel_clk) begin
        if (pixel_reset)
            fifo_prefilled <= 1'b0;
        else
            fifo_prefilled <= fifo_prefilled_sync;
    end

    initial begin
        if ((PREFILL_PIXELS < 1) || (PREFILL_PIXELS >= FIFO_DEPTH))
            $error("PREFILL_PIXELS must be between 1 and FIFO_DEPTH-1");
    end
endmodule
