// Standalone CF7A100B HDMI output test.
//
// This top deliberately contains no MicroBlaze, MIG, VDMA, FIFO or sprite
// engine. A stable picture proves the board clock, HDMI clock generation,
// timing generator, TMDS encoder/serializer and physical HDMI pins.
module hdmi_colorbar_top (
    input  logic       sys_clk_i,
    input  logic       sys_rst_n,

    output logic       tmds_clk_p,
    output logic       tmds_clk_n,
    output logic [2:0] tmds_data_p,
    output logic [2:0] tmds_data_n,

    output logic [3:0] led
);
    logic pixel_clk;
    logic pixel_clk_5x;
    logic clocks_locked;
    logic frame_start;
    logic [5:0] frame_count;

    clk_wiz_hdmi_720p hdmi_clocks (
        .clk_out1 (pixel_clk),
        .clk_out2 (pixel_clk_5x),
        .reset    (~sys_rst_n),
        .locked   (clocks_locked),
        .clk_in1  (sys_clk_i)
    );

    hdmi_720p #(
        .PIXEL_READ_LATENCY(0)
    ) hdmi (
        .pixel_clk      (pixel_clk),
        .pixel_clk_5x   (pixel_clk_5x),
        .clocks_locked  (clocks_locked),
        .reset          (~sys_rst_n),
        .pattern_sel    (2'd1),
        .rgb565         (16'h0000),
        .solid_rgb565   (16'h0000),
        .pixel_x        (),
        .pixel_y        (),
        .pixel_de       (),
        .frame_start    (frame_start),
        .pixel_req      (),
        .pixel_req_x    (),
        .pixel_req_y    (),
        .hdmi_clk_p     (tmds_clk_p),
        .hdmi_clk_n     (tmds_clk_n),
        .hdmi_data_p    (tmds_data_p),
        .hdmi_data_n    (tmds_data_n)
    );

    always_ff @(posedge pixel_clk or negedge clocks_locked) begin
        if (!clocks_locked)
            frame_count <= '0;
        else if (frame_start)
            frame_count <= frame_count + 1'b1;
    end

    // LED0: HDMI clocks locked.
    // LED1: frame heartbeat, approximately one on/off cycle per two seconds.
    // LED2: board reset has been released.
    // LED3: reserved; off means no locally detected fault.
    assign led[0] = clocks_locked;
    assign led[1] = frame_count[5];
    assign led[2] = sys_rst_n;
    assign led[3] = 1'b0;
endmodule
