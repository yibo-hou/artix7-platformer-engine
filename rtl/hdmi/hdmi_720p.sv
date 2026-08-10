// Reusable 1280x720p60 HDMI/DVI video output for Xilinx Artix-7.
//
// Input clocks: 74.25 MHz pixel clock and phase-related 371.25 MHz clock.
// Generate both clocks from the same Vivado Clocking Wizard/MMCM.
// Video input: RGB565, synchronous to pixel_clk
// Output: DVI-compatible TMDS (video only; no HDMI audio/data islands)
module hdmi_720p #(
    // Fixed latency, in pixel_clk cycles, from pixel_req to valid rgb565.
    // Set this to the FIFO output latency, not to the variable DDR3 latency.
    parameter integer PIXEL_READ_LATENCY = 1
) (
    input  logic        pixel_clk,
    input  logic        pixel_clk_5x,
    input  logic        clocks_locked,
    input  logic        reset,

    // 0: external RGB565, 1: color bars, 2: solid color, 3: checkerboard
    input  logic [1:0]  pattern_sel,
    input  logic [15:0] rgb565,
    input  logic [15:0] solid_rgb565,

    // Pixel-side interface for a future renderer/framebuffer.
    output logic [10:0] pixel_x,
    output logic [9:0]  pixel_y,
    output logic        pixel_de,
    output logic        frame_start,
    output logic        pixel_req,
    output logic [10:0] pixel_req_x,
    output logic [9:0]  pixel_req_y,

    output logic        hdmi_clk_p,
    output logic        hdmi_clk_n,
    output logic [2:0]  hdmi_data_p,
    output logic [2:0]  hdmi_data_n
);
    logic video_reset;
    logic hsync;
    logic vsync;
    logic [7:0] red;
    logic [7:0] green;
    logic [7:0] blue;
    logic [7:0] video_red;
    logic [7:0] video_green;
    logic [7:0] video_blue;
    logic       video_de;
    logic       video_hsync;
    logic       video_vsync;
    logic [9:0] tmds_red;
    logic [9:0] tmds_green;
    logic [9:0] tmds_blue;
    logic       tmds_clock_serial;
    logic [2:0] tmds_data_serial;

    // Hold all pixel-domain logic reset until the external clocks are stable.
    always_ff @(posedge pixel_clk or negedge clocks_locked) begin
        if (!clocks_locked)
            video_reset <= 1'b1;
        else
            video_reset <= reset;
    end

    hdmi_timing_720p #(
        .PIXEL_READ_LATENCY(PIXEL_READ_LATENCY)
    ) timing (
        .pixel_clk   (pixel_clk),
        .reset       (video_reset),
        .pixel_x     (pixel_x),
        .pixel_y     (pixel_y),
        .de          (pixel_de),
        .hsync       (hsync),
        .vsync       (vsync),
        .frame_start (frame_start),
        .pixel_req   (pixel_req),
        .pixel_req_x (pixel_req_x),
        .pixel_req_y (pixel_req_y)
    );

    hdmi_rgb565_source source (
        .pattern_sel  (pattern_sel),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .de           (pixel_de),
        .rgb565       (rgb565),
        .solid_rgb565 (solid_rgb565),
        .red          (red),
        .green        (green),
        .blue         (blue)
    );

    // Pipeline RGB and timing as one tuple before TMDS encoding.  This gives
    // the framebuffer/FIFO/HUD path a complete pixel period to settle while
    // keeping DE and sync aligned with their corresponding color value.
    always_ff @(posedge pixel_clk) begin
        if (video_reset) begin
            video_red   <= '0;
            video_green <= '0;
            video_blue  <= '0;
            video_de    <= 1'b0;
            video_hsync <= 1'b0;
            video_vsync <= 1'b0;
        end else begin
            video_red   <= red;
            video_green <= green;
            video_blue  <= blue;
            video_de    <= pixel_de;
            video_hsync <= hsync;
            video_vsync <= vsync;
        end
    end

    // Control symbols are carried only by channel 0 during blanking.
    hdmi_tmds_encoder encode_blue (
        .pixel_clk (pixel_clk),
        .reset     (video_reset),
        .video     (video_blue),
        .control   ({video_vsync, video_hsync}),
        .de        (video_de),
        .tmds      (tmds_blue)
    );

    hdmi_tmds_encoder encode_green (
        .pixel_clk (pixel_clk),
        .reset     (video_reset),
        .video     (video_green),
        .control   (2'b00),
        .de        (video_de),
        .tmds      (tmds_green)
    );

    hdmi_tmds_encoder encode_red (
        .pixel_clk (pixel_clk),
        .reset     (video_reset),
        .video     (video_red),
        .control   (2'b00),
        .de        (video_de),
        .tmds      (tmds_red)
    );

    hdmi_tmds_serializer serialize_blue (
        .pixel_clk    (pixel_clk),
        .pixel_clk_5x (pixel_clk_5x),
        .reset        (video_reset),
        .parallel     (tmds_blue),
        .serial       (tmds_data_serial[0])
    );

    hdmi_tmds_serializer serialize_green (
        .pixel_clk    (pixel_clk),
        .pixel_clk_5x (pixel_clk_5x),
        .reset        (video_reset),
        .parallel     (tmds_green),
        .serial       (tmds_data_serial[1])
    );

    hdmi_tmds_serializer serialize_red (
        .pixel_clk    (pixel_clk),
        .pixel_clk_5x (pixel_clk_5x),
        .reset        (video_reset),
        .parallel     (tmds_red),
        .serial       (tmds_data_serial[2])
    );

    // TMDS clock is a fixed 10-bit DDR pattern, LSB transmitted first.
    hdmi_tmds_serializer serialize_clock (
        .pixel_clk    (pixel_clk),
        .pixel_clk_5x (pixel_clk_5x),
        .reset        (video_reset),
        .parallel     (10'b1111100000),
        .serial       (tmds_clock_serial)
    );

    OBUFDS #(
        .IOSTANDARD("TMDS_33"),
        .SLEW("FAST")
    ) clock_out (
        .I  (tmds_clock_serial),
        .O  (hdmi_clk_p),
        .OB (hdmi_clk_n)
    );

    genvar lane;
    generate
        for (lane = 0; lane < 3; lane = lane + 1) begin : gen_data_out
            OBUFDS #(
                .IOSTANDARD("TMDS_33"),
                .SLEW("FAST")
            ) data_out (
                .I  (tmds_data_serial[lane]),
                .O  (hdmi_data_p[lane]),
                .OB (hdmi_data_n[lane])
            );
        end
    endgenerate
endmodule
