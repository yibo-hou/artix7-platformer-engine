`timescale 1ns/1ps

module tb_sprite_frame_stream;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic enable = 1'b0;
    logic pixel_req;
    logic [10:0] pixel_req_x;
    logic [9:0] pixel_req_y;
    logic pixel_req_ready;
    logic [15:0] rgb565;
    logic rgb_valid;
    logic rgb_ready;
    logic [10:0] rgb_x;
    logic [9:0] rgb_y;
    logic [15:0] tdata;
    logic [1:0] tkeep;
    logic tvalid;
    logic tready = 1'b1;
    logic tuser;
    logic tlast;
    logic frame_active;
    logic frame_done;
    integer accepted = 0;
    integer cycles = 0;

    always #5 clk = ~clk;

    sprite_frame_stream #(
        .FRAME_WIDTH(4),
        .FRAME_HEIGHT(3)
    ) dut (
        .pixel_clk(clk),
        .reset(reset),
        .enable(enable),
        .pixel_req(pixel_req),
        .pixel_req_x(pixel_req_x),
        .pixel_req_y(pixel_req_y),
        .pixel_req_ready(pixel_req_ready),
        .rgb565(rgb565),
        .rgb_valid(rgb_valid),
        .rgb_ready(rgb_ready),
        .rgb_x(rgb_x),
        .rgb_y(rgb_y),
        .m_axis_tdata(tdata),
        .m_axis_tkeep(tkeep),
        .m_axis_tvalid(tvalid),
        .m_axis_tready(tready),
        .m_axis_tuser(tuser),
        .m_axis_tlast(tlast),
        .frame_active(frame_active),
        .frame_done(frame_done)
    );

    // One-entry renderer model that obeys output backpressure.
    assign pixel_req_ready = !rgb_valid || rgb_ready;
    always_ff @(posedge clk) begin
        if (reset) begin
            rgb_valid <= 1'b0;
            rgb565 <= '0;
            rgb_x <= '0;
            rgb_y <= '0;
        end else if (pixel_req_ready) begin
            rgb_valid <= pixel_req;
            if (pixel_req) begin
                rgb_x <= pixel_req_x;
                rgb_y <= pixel_req_y;
                rgb565 <= {5'(pixel_req_y), 6'(pixel_req_x), 5'(pixel_req_x)};
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!reset) begin
            cycles <= cycles + 1;
            // Periodically stop the VDMA sink.
            tready <= (cycles % 5) != 2;

            if (tvalid && tready) begin
                if (rgb_x != accepted % 4 || rgb_y != accepted / 4)
                    $fatal(1, "coordinate mismatch at pixel %0d", accepted);
                if (tuser != (accepted == 0))
                    $fatal(1, "wrong SOF at pixel %0d", accepted);
                if (tlast != ((accepted % 4) == 3))
                    $fatal(1, "wrong EOL at pixel %0d", accepted);
                if (tkeep != 2'b11)
                    $fatal(1, "wrong TKEEP");
                accepted <= accepted + 1;
            end

            if (frame_done) begin
                if (accepted != 12)
                    $fatal(1, "frame ended after %0d pixels", accepted);
                $display("PASS: raster frame stream survives AXIS backpressure");
                $finish;
            end
        end
    end

    initial begin
        repeat (3) @(posedge clk);
        reset <= 1'b0;
        enable <= 1'b1;
        repeat (200) @(posedge clk);
        $fatal(1, "timeout");
    end
endmodule
