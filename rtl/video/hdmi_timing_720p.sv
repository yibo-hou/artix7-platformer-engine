module hdmi_timing_720p #(
    parameter integer PIXEL_READ_LATENCY = 1
) (
    input  logic        pixel_clk,
    input  logic        reset,
    output logic [10:0] pixel_x,
    output logic [9:0]  pixel_y,
    output logic        de,
    output logic        hsync,
    output logic        vsync,
    output logic        frame_start,
    output logic        pixel_req,
    output logic [10:0] pixel_req_x,
    output logic [9:0]  pixel_req_y
);
    localparam integer H_ACTIVE = 1280;
    localparam integer H_FRONT  = 110;
    localparam integer H_SYNC   = 40;
    localparam integer H_BACK   = 220;
    localparam integer H_TOTAL  = 1650;
    localparam integer V_ACTIVE = 720;
    localparam integer V_FRONT  = 5;
    localparam integer V_SYNC   = 5;
    localparam integer V_BACK   = 20;
    localparam integer V_TOTAL  = 750;

    logic [10:0] h_count;
    logic [9:0]  v_count;
    logic [11:0] request_h_sum;
    logic [10:0] request_v;

    always_ff @(posedge pixel_clk) begin
        if (reset) begin
            // Start in vertical blanking. This gives the DDR/FIFO controller
            // time to prefill before the first visible frame.
            h_count <= H_ACTIVE;
            v_count <= V_ACTIVE;
        end else if (h_count == H_TOTAL - 1) begin
            h_count <= '0;
            if (v_count == V_TOTAL - 1)
                v_count <= '0;
            else
                v_count <= v_count + 1'b1;
        end else begin
            h_count <= h_count + 1'b1;
        end
    end

    always_comb begin
        pixel_x = h_count;
        pixel_y = v_count;
        de = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
        hsync = (h_count >= H_ACTIVE + H_FRONT) &&
                (h_count <  H_ACTIVE + H_FRONT + H_SYNC);
        vsync = (v_count >= V_ACTIVE + V_FRONT) &&
                (v_count <  V_ACTIVE + V_FRONT + V_SYNC);
        frame_start = (h_count == 0) && (v_count == 0);

        // Look ahead by the FIFO's fixed output latency. DDR3's variable
        // latency must already have been absorbed by the upstream FIFO.
        request_h_sum = h_count + PIXEL_READ_LATENCY;
        request_v = v_count;
        if (request_h_sum >= H_TOTAL) begin
            request_h_sum = request_h_sum - H_TOTAL;
            if (v_count == V_TOTAL - 1)
                request_v = 0;
            else
                request_v = v_count + 1'b1;
        end

        pixel_req_x = request_h_sum[10:0];
        pixel_req_y = request_v[9:0];
        pixel_req = (request_h_sum < H_ACTIVE) &&
                    (request_v < V_ACTIVE);
    end

    initial begin
        if ((PIXEL_READ_LATENCY < 0) || (PIXEL_READ_LATENCY >= H_TOTAL))
            $error("PIXEL_READ_LATENCY must be between 0 and 1649");
    end
endmodule
