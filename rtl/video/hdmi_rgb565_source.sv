module hdmi_rgb565_source (
    input  logic [1:0]  pattern_sel,
    input  logic [10:0] pixel_x,
    input  logic [9:0]  pixel_y,
    input  logic        de,
    input  logic [15:0] rgb565,
    input  logic [15:0] solid_rgb565,
    output logic [7:0]  red,
    output logic [7:0]  green,
    output logic [7:0]  blue
);
    logic [15:0] selected_rgb565;

    function automatic logic [15:0] color_bar(input logic [2:0] bar);
        case (bar)
            3'd0: color_bar = 16'hFFFF; // white
            3'd1: color_bar = 16'hFFE0; // yellow
            3'd2: color_bar = 16'h07FF; // cyan
            3'd3: color_bar = 16'h07E0; // green
            3'd4: color_bar = 16'hF81F; // magenta
            3'd5: color_bar = 16'hF800; // red
            3'd6: color_bar = 16'h001F; // blue
            default: color_bar = 16'h0000; // black
        endcase
    endfunction

    always_comb begin
        case (pattern_sel)
            2'd1: selected_rgb565 = color_bar(pixel_x / 160);
            2'd2: selected_rgb565 = solid_rgb565;
            2'd3: selected_rgb565 =
                (pixel_x[5] ^ pixel_y[5]) ? 16'hFFFF : 16'h0000;
            default: selected_rgb565 = rgb565;
        endcase

        if (de) begin
            // Bit replication maps the full RGB565 range to 8-bit channels.
            red   = {selected_rgb565[15:11], selected_rgb565[15:13]};
            green = {selected_rgb565[10:5],  selected_rgb565[10:9]};
            blue  = {selected_rgb565[4:0],   selected_rgb565[4:2]};
        end else begin
            red   = 8'h00;
            green = 8'h00;
            blue  = 8'h00;
        end
    end
endmodule
