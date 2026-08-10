// 10:1 DDR serializer. parallel[0] is transmitted first.
module hdmi_tmds_serializer (
    input  logic       pixel_clk,
    input  logic       pixel_clk_5x,
    input  logic       reset,
    input  logic [9:0] parallel,
    output logic       serial
);
    logic shift1;
    logic shift2;

    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"),
        .DATA_RATE_TQ("SDR"),
        .DATA_WIDTH(10),
        .SERDES_MODE("SLAVE"),
        .TRISTATE_WIDTH(1)
    ) slave (
        .CLK       (pixel_clk_5x),
        .CLKDIV    (pixel_clk),
        .D1        (1'b0),
        .D2        (1'b0),
        .D3        (parallel[8]),
        .D4        (parallel[9]),
        .D5        (1'b0),
        .D6        (1'b0),
        .D7        (1'b0),
        .D8        (1'b0),
        .OCE       (1'b1),
        .RST       (reset),
        .SHIFTIN1  (1'b0),
        .SHIFTIN2  (1'b0),
        .SHIFTOUT1 (shift1),
        .SHIFTOUT2 (shift2),
        .T1        (1'b0),
        .T2        (1'b0),
        .T3        (1'b0),
        .T4        (1'b0),
        .TBYTEIN   (1'b0),
        .TCE       (1'b0)
    );

    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"),
        .DATA_RATE_TQ("SDR"),
        .DATA_WIDTH(10),
        .SERDES_MODE("MASTER"),
        .TRISTATE_WIDTH(1)
    ) master (
        .CLK       (pixel_clk_5x),
        .CLKDIV    (pixel_clk),
        .D1        (parallel[0]),
        .D2        (parallel[1]),
        .D3        (parallel[2]),
        .D4        (parallel[3]),
        .D5        (parallel[4]),
        .D6        (parallel[5]),
        .D7        (parallel[6]),
        .D8        (parallel[7]),
        .OCE       (1'b1),
        .OQ        (serial),
        .RST       (reset),
        .SHIFTIN1  (shift1),
        .SHIFTIN2  (shift2),
        .T1        (1'b0),
        .T2        (1'b0),
        .T3        (1'b0),
        .T4        (1'b0),
        .TBYTEIN   (1'b0),
        .TCE       (1'b0)
    );
endmodule
