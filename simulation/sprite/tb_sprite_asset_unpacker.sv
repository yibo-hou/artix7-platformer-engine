`timescale 1ns/1ps

module tb_sprite_asset_unpacker;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [255:0] tdata = '0;
    logic [31:0] tkeep = '0;
    logic tlast = 1'b0;
    logic tvalid = 1'b0;
    logic clear_status = 1'b0;
    logic tready;
    logic busy;
    logic done;
    logic error;
    logic sprite_wr_en;
    logic [13:0] sprite_wr_addr;
    logic [3:0] sprite_wr_index;
    integer writes = 0;

    always #5 clk = ~clk;

    sprite_asset_unpacker dut (
        .pixel_clk(clk),
        .reset(reset),
        .s_axis_tdata(tdata),
        .s_axis_tkeep(tkeep),
        .s_axis_tlast(tlast),
        .s_axis_tvalid(tvalid),
        .s_axis_tready(tready),
        .dest_kind(2'd2),
        .dest_addr(16'd1024),
        .clear_status(clear_status),
        .busy(busy),
        .done(done),
        .error(error),
        .tilemap_wr_en(),
        .tilemap_wr_addr(),
        .tilemap_wr_tile(),
        .tile_gfx_wr_en(),
        .tile_gfx_wr_addr(),
        .tile_gfx_wr_index(),
        .sprite_gfx_wr_en(sprite_wr_en),
        .sprite_gfx_wr_addr(sprite_wr_addr),
        .sprite_gfx_wr_index(sprite_wr_index),
        .palette_wr_en(),
        .palette_wr_index(),
        .palette_wr_rgb565()
    );

    always_ff @(posedge clk) begin
        if (sprite_wr_en) begin
            if (sprite_wr_addr !== 1024 + writes)
                $fatal(1, "wrong address: %0d", sprite_wr_addr);
            if (sprite_wr_index !== writes + 1)
                $fatal(1, "wrong pixel index: %0d", sprite_wr_index);
            writes <= writes + 1;
        end
    end

    initial begin
        repeat (3) @(posedge clk);
        reset <= 1'b0;

        @(negedge clk);
        tdata[7:0]   = 8'h01;
        tdata[15:8]  = 8'h02;
        tdata[23:16] = 8'h03;
        tkeep = 32'h0000_0007;
        tlast = 1'b1;
        tvalid = 1'b1;

        do @(posedge clk); while (!tready);
        @(negedge clk);
        tvalid = 1'b0;

        wait (done);
        @(posedge clk);
        if (writes != 3)
            $fatal(1, "expected 3 writes, got %0d", writes);
        if (error)
            $fatal(1, "unexpected unpacker error");

        @(negedge clk);
        clear_status = 1'b1;
        @(negedge clk);
        clear_status = 1'b0;
        @(posedge clk);
        if (done || error)
            $fatal(1, "status did not clear");

        $display("PASS: AXIS partial final beat unpacked correctly");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "timeout");
    end
endmodule
