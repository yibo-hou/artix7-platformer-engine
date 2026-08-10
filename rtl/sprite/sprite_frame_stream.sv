// Drives sprite_engine in raster order and exposes the rendered frame as an
// AXI4-Stream video source suitable for AXI VDMA S2MM.
//
// tuser marks start-of-frame and tlast marks end-of-line. The stream contains
// active pixels only: 1280 pixels on each of 720 lines.
module sprite_frame_stream #(
    parameter integer FRAME_WIDTH  = 1280,
    parameter integer FRAME_HEIGHT = 720
) (
    input  logic pixel_clk,
    input  logic reset,
    input  logic enable,

    // Request side of sprite_engine.
    output logic        pixel_req,
    output logic [10:0] pixel_req_x,
    output logic [9:0]  pixel_req_y,
    input  logic        pixel_req_ready,

    // Response side of sprite_engine.
    input  logic [15:0] rgb565,
    input  logic        rgb_valid,
    output logic        rgb_ready,
    input  logic [10:0] rgb_x,
    input  logic [9:0]  rgb_y,

    // AXI4-Stream video output to AXI VDMA S_AXIS_S2MM.
    output logic [15:0] m_axis_tdata,
    output logic [1:0]  m_axis_tkeep,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready,
    output logic        m_axis_tuser,
    output logic        m_axis_tlast,

    output logic        frame_active,
    output logic        frame_done
);
    logic [10:0] request_x;
    logic [9:0]  request_y;
    logic        requests_complete;
    logic        request_fire;
    logic        output_fire;

    assign pixel_req = frame_active && !requests_complete;
    assign pixel_req_x = request_x;
    assign pixel_req_y = request_y;
    assign request_fire = pixel_req && pixel_req_ready;

    assign m_axis_tdata  = rgb565;
    assign m_axis_tkeep  = 2'b11;
    assign m_axis_tvalid = rgb_valid;
    assign m_axis_tuser  = rgb_valid && (rgb_x == 0) && (rgb_y == 0);
    assign m_axis_tlast  = rgb_valid && (rgb_x == FRAME_WIDTH - 1);
    assign rgb_ready     = m_axis_tready;
    assign output_fire   = m_axis_tvalid && m_axis_tready;

    always_ff @(posedge pixel_clk) begin
        if (reset) begin
            request_x         <= '0;
            request_y         <= '0;
            requests_complete <= 1'b0;
            frame_active      <= 1'b0;
            frame_done        <= 1'b0;
        end else begin
            frame_done <= 1'b0;

            if (!enable) begin
                request_x         <= '0;
                request_y         <= '0;
                requests_complete <= 1'b0;
                frame_active      <= 1'b0;
            end else if (!frame_active) begin
                // Start the next frame. Continuous operation is intentional:
                // VDMA controls the pace through tready.
                request_x         <= '0;
                request_y         <= '0;
                requests_complete <= 1'b0;
                frame_active      <= 1'b1;
            end else begin
                if (request_fire) begin
                    if ((request_x == FRAME_WIDTH - 1) &&
                        (request_y == FRAME_HEIGHT - 1)) begin
                        requests_complete <= 1'b1;
                    end else if (request_x == FRAME_WIDTH - 1) begin
                        request_x <= '0;
                        request_y <= request_y + 1'b1;
                    end else begin
                        request_x <= request_x + 1'b1;
                    end
                end

                if (output_fire &&
                    (rgb_x == FRAME_WIDTH - 1) &&
                    (rgb_y == FRAME_HEIGHT - 1)) begin
                    frame_active <= 1'b0;
                    frame_done   <= 1'b1;
                end
            end
        end
    end

    initial begin
        if ((FRAME_WIDTH < 1) || (FRAME_WIDTH > 2048))
            $error("FRAME_WIDTH must be between 1 and 2048");
        if ((FRAME_HEIGHT < 1) || (FRAME_HEIGHT > 1024))
            $error("FRAME_HEIGHT must be between 1 and 1024");
    end
endmodule
