module hdmi_tmds_encoder (
    input  logic       pixel_clk,
    input  logic       reset,
    input  logic [7:0] video,
    input  logic [1:0] control,
    input  logic       de,
    output logic [9:0] tmds
);
    logic [8:0] q_m;
    logic [3:0] video_ones;
    logic [3:0] q_m_ones;
    logic       use_xnor;
    logic signed [5:0] disparity;
    integer i;

    always_comb begin
        video_ones = video[0] + video[1] + video[2] + video[3] +
                     video[4] + video[5] + video[6] + video[7];
        use_xnor = (video_ones > 4) ||
                   ((video_ones == 4) && (video[0] == 1'b0));

        q_m[0] = video[0];
        for (i = 1; i < 8; i = i + 1)
            q_m[i] = use_xnor ? ~(q_m[i-1] ^ video[i])
                              :  (q_m[i-1] ^ video[i]);
        q_m[8] = ~use_xnor;

        q_m_ones = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                   q_m[4] + q_m[5] + q_m[6] + q_m[7];
    end

    always_ff @(posedge pixel_clk) begin
        if (reset) begin
            tmds      <= 10'b1101010100;
            disparity <= '0;
        end else if (!de) begin
            disparity <= '0;
            case (control)
                2'b00: tmds <= 10'b1101010100;
                2'b01: tmds <= 10'b0010101011;
                2'b10: tmds <= 10'b0101010100;
                default: tmds <= 10'b1010101011;
            endcase
        end else if ((disparity == 0) || (q_m_ones == 4)) begin
            tmds[9]   <= ~q_m[8];
            tmds[8]   <= q_m[8];
            tmds[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
            if (q_m[8])
                disparity <= disparity + $signed({1'b0, q_m_ones, 1'b0}) - 8;
            else
                disparity <= disparity + 8 - $signed({1'b0, q_m_ones, 1'b0});
        end else if (((disparity > 0) && (q_m_ones > 4)) ||
                     ((disparity < 0) && (q_m_ones < 4))) begin
            tmds[9]   <= 1'b1;
            tmds[8]   <= q_m[8];
            tmds[7:0] <= ~q_m[7:0];
            disparity <= disparity + (q_m[8] ? 2 : 0)
                         + 8 - $signed({1'b0, q_m_ones, 1'b0});
        end else begin
            tmds[9]   <= 1'b0;
            tmds[8]   <= q_m[8];
            tmds[7:0] <= q_m[7:0];
            disparity <= disparity - (q_m[8] ? 0 : 2)
                         + $signed({1'b0, q_m_ones, 1'b0}) - 8;
        end
    end
endmodule
