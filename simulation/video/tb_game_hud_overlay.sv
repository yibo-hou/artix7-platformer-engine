module tb_game_hud_overlay;
    logic [10:0] pixel_x;
    logic [9:0] pixel_y;
    logic [15:0] background;
    logic [5:0] coin_count;
    logic [1:0] health;
    logic goal_reached;
    logic power_active;
    logic [15:0] rgb565;

    game_hud_overlay dut (
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .background(background),
        .coin_count(coin_count),
        .health(health),
        .goal_reached(goal_reached),
        .power_active(power_active),
        .rgb565(rgb565)
    );

    task automatic check_pixel(
        input logic [10:0] x,
        input logic [9:0] y,
        input logic goal,
        input logic [15:0] expected
    );
        begin
            pixel_x = x;
            pixel_y = y;
            goal_reached = goal;
            #1;
            if (rgb565 !== expected)
                $fatal(1, "pixel (%0d,%0d) goal=%0d got=%h expected=%h",
                       x, y, goal, rgb565, expected);
        end
    endtask

    initial begin
        background = 16'h1234;
        coin_count = 6'd17;
        health = 2'd2;
        power_active = 1'b0;

        check_pixel(11'd500, 10'd200, 1'b0, 16'h1234);
        check_pixel(11'd424, 10'd292, 1'b0, 16'h1234);
        check_pixel(11'd424, 10'd292, 1'b1, 16'hFFE0);
        check_pixel(11'd440, 10'd310, 1'b1, 16'h2104);
        // Top-left pixel of the first L in "LEVEL CLEAR".
        check_pixel(11'd464, 10'd306, 1'b1, 16'hFFFF);
        check_pixel(11'd1020, 10'd28, 1'b0, 16'hF800);
        check_pixel(11'd1092, 10'd28, 1'b0, 16'hF800);
        check_pixel(11'd1164, 10'd28, 1'b0, 16'h4208);

        power_active = 1'b1;
        check_pixel(11'd488, 10'd16, 1'b0, 16'hFFE0);
        // First lit pixel in the S of the STAR indicator.
        check_pixel(11'd572, 10'd26, 1'b0, 16'hFFFF);
        power_active = 1'b0;

        health = 2'd0;
        check_pixel(11'd456, 10'd292, 1'b0, 16'hF800);
        check_pixel(11'd480, 10'd310, 1'b0, 16'h2104);
        // First lit pixel of the G in "GAME OVER".
        check_pixel(11'd508, 10'd306, 1'b0, 16'hFFFF);

        $display("HUD overlay goal/failure banner test passed");
        $finish;
    end
endmodule
