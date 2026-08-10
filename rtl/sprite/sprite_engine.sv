// Mario-oriented tile and sprite renderer.
//
// Native resolution: 1280x720.
// Color format:        RGB565.
// Tile layer:          128x64 tiles, 16x16 pixels per tile.
// Sprites:             16 slots, 32x32 pixels each.
// Pixel format:        4-bit index into a shared 16-entry RGB565 palette.
//
// The configuration interface is synchronous to pixel_clk. An AXI-Lite
// wrapper or CDC command FIFO can be added between MicroBlaze and these ports.
module sprite_engine #(
    parameter integer TILE_COUNT   = 64,
    parameter integer SPRITE_COUNT = 16
) (
    input  logic pixel_clk,
    input  logic reset,

    // Render request interface. For a framebuffer, present pixels in raster
    // order and keep pixel_req/x/y stable until pixel_req_ready is high.
    input  logic        pixel_req,
    input  logic [10:0] pixel_req_x,
    input  logic [9:0]  pixel_req_y,
    output logic        pixel_req_ready,

    // Rendered pixel stream. The framebuffer writer may apply backpressure by
    // deasserting rgb_ready; the complete rendering pipeline then stalls.
    output logic [15:0] rgb565,
    output logic        rgb_valid,
    input  logic        rgb_ready,
    output logic [10:0] rgb_x,
    output logic [9:0]  rgb_y,
    output logic        rgb_frame_start,
    output logic        rgb_frame_end,

    // Camera position in native pixel coordinates.
    input  logic [10:0] scroll_x,
    input  logic [9:0]  scroll_y,

    // 128x64 tile-map write port: address = tile_y * 128 + tile_x.
    input  logic        tilemap_wr_en,
    input  logic [12:0] tilemap_wr_addr,
    input  logic [$clog2(TILE_COUNT)-1:0] tilemap_wr_tile,

    // Tile graphics: 256 indexed pixels per 16x16 tile.
    // address = tile_id * 256 + local_y * 16 + local_x.
    input  logic        tile_gfx_wr_en,
    input  logic [$clog2(TILE_COUNT*256)-1:0] tile_gfx_wr_addr,
    input  logic [3:0]  tile_gfx_wr_index,

    // Sprite graphics: 1024 indexed pixels stored independently per slot.
    // address = sprite_slot * 1024 + local_y * 32 + local_x.
    input  logic        sprite_gfx_wr_en,
    input  logic [$clog2(SPRITE_COUNT*1024)-1:0] sprite_gfx_wr_addr,
    input  logic [3:0]  sprite_gfx_wr_index,

    // Sprite attribute write. Bits:
    // [0] enable, [11:1] x, [21:12] y, [22] flip_x, [23] flip_y.
    input  logic        sprite_attr_wr_en,
    input  logic [$clog2(SPRITE_COUNT)-1:0] sprite_attr_wr_slot,
    input  logic [23:0] sprite_attr_wr_data,

    // Shared RGB565 palette. Index zero is tile background and transparent
    // for sprites.
    input  logic        palette_wr_en,
    input  logic [3:0]  palette_wr_index,
    input  logic [15:0] palette_wr_rgb565
);
    localparam integer TILEMAP_SIZE = 128 * 64;
    localparam integer TILE_ID_W = $clog2(TILE_COUNT);
    localparam integer TILE_GFX_ADDR_W = $clog2(TILE_COUNT * 256);
    localparam integer SPRITE_GFX_ADDR_W = $clog2(SPRITE_COUNT * 1024);

    // Asynchronous reads are intentional: they keep the renderer at a fixed
    // three-cycle latency. Explicit distributed RAM avoids accidental BRAM
    // inference with incompatible asynchronous-read behavior.
    (* ram_style = "distributed" *)
    logic [TILE_ID_W-1:0] tilemap [0:TILEMAP_SIZE-1];

    (* ram_style = "distributed" *)
    logic [3:0] tile_graphics [0:TILE_COUNT*256-1];

    // One independent bank per sprite gives 16 parallel pixel reads without
    // replicating a monolithic multi-read-port memory.
    (* ram_style = "distributed" *)
    logic [3:0] sprite_graphics [0:SPRITE_COUNT-1][0:1023];
    logic [15:0] palette [0:15];

    logic sprite_enable [0:SPRITE_COUNT-1];
    logic [10:0] sprite_x [0:SPRITE_COUNT-1];
    logic [9:0]  sprite_y [0:SPRITE_COUNT-1];
    logic sprite_flip_x [0:SPRITE_COUNT-1];
    logic sprite_flip_y [0:SPRITE_COUNT-1];

    // Pipeline stage 0: requested coordinates converted to world coordinates.
    logic        valid_s0;
    logic [10:0] screen_x_s0;
    logic [9:0]  screen_y_s0;
    logic [11:0] world_x_s0;
    logic [10:0] world_y_s0;

    // Pipeline stage 1: tile ID and coordinates.
    logic        valid_s1;
    logic [10:0] screen_x_s1;
    logic [9:0]  screen_y_s1;
    logic [3:0]  tile_local_x_s1;
    logic [3:0]  tile_local_y_s1;
    logic [TILE_ID_W-1:0] tile_id_s1;

    // Pipeline stage 2: resolved tile and highest-priority sprite indices.
    logic        valid_s2;
    logic [10:0] screen_x_s2;
    logic [9:0]  screen_y_s2;
    logic [3:0]  tile_index_s2;
    logic [3:0]  sprite_index_s2;
    logic        sprite_opaque_s2;

    logic [3:0] sprite_index_comb;
    logic       sprite_opaque_comb;
    logic [4:0] local_x;
    logic [4:0] local_y;
    integer sprite_i;
    integer tilemap_read_addr;
    integer tile_gfx_read_addr;
    integer sprite_gfx_read_addr;
    integer sprite_write_slot;
    integer sprite_write_pixel;
    logic pipeline_advance;

    // A single clock-enable stalls every pipeline stage together. This keeps
    // coordinates, tile data and sprite data aligned while a downstream FIFO
    // or MIG writer is unable to accept a pixel.
    assign pipeline_advance = !valid_s2 || rgb_ready;
    assign pixel_req_ready = pipeline_advance;

    // Highest numbered enabled sprite wins. Palette index zero is transparent.
    always_comb begin
        sprite_index_comb = 4'h0;
        sprite_opaque_comb = 1'b0;
        local_x = 4'h0;
        local_y = 4'h0;
        sprite_gfx_read_addr = 0;

        for (sprite_i = 0; sprite_i < SPRITE_COUNT; sprite_i = sprite_i + 1) begin
            if (sprite_enable[sprite_i] &&
                (screen_x_s1 >= sprite_x[sprite_i]) &&
                (screen_x_s1 < sprite_x[sprite_i] + 32) &&
                (screen_y_s1 >= sprite_y[sprite_i]) &&
                (screen_y_s1 < sprite_y[sprite_i] + 32)) begin

                local_x = screen_x_s1 - sprite_x[sprite_i];
                local_y = screen_y_s1 - sprite_y[sprite_i];
                if (sprite_flip_x[sprite_i])
                    local_x = 31 - local_x;
                if (sprite_flip_y[sprite_i])
                    local_y = 31 - local_y;

                sprite_gfx_read_addr = local_y * 32 + local_x;
                if (sprite_graphics[sprite_i][sprite_gfx_read_addr] != 0) begin
                    sprite_index_comb =
                        sprite_graphics[sprite_i][sprite_gfx_read_addr];
                    sprite_opaque_comb = 1'b1;
                end
            end
        end
    end

    always_ff @(posedge pixel_clk) begin
        if (tilemap_wr_en)
            tilemap[tilemap_wr_addr] <= tilemap_wr_tile;
        if (tile_gfx_wr_en)
            tile_graphics[tile_gfx_wr_addr] <= tile_gfx_wr_index;
        if (sprite_gfx_wr_en) begin
            sprite_write_slot = sprite_gfx_wr_addr >> 10;
            sprite_write_pixel = sprite_gfx_wr_addr[9:0];
            sprite_graphics[sprite_write_slot][sprite_write_pixel]
                <= sprite_gfx_wr_index;
        end
        if (palette_wr_en)
            palette[palette_wr_index] <= palette_wr_rgb565;

        if (sprite_attr_wr_en) begin
            sprite_enable[sprite_attr_wr_slot] <= sprite_attr_wr_data[0];
            sprite_x[sprite_attr_wr_slot] <= sprite_attr_wr_data[11:1];
            sprite_y[sprite_attr_wr_slot] <= sprite_attr_wr_data[21:12];
            sprite_flip_x[sprite_attr_wr_slot] <= sprite_attr_wr_data[22];
            sprite_flip_y[sprite_attr_wr_slot] <= sprite_attr_wr_data[23];
        end
    end

    always_comb begin
        tilemap_read_addr = world_y_s0[9:4] * 128 + world_x_s0[10:4];
        tile_gfx_read_addr =
            tile_id_s1 * 256 + tile_local_y_s1 * 16 + tile_local_x_s1;
    end

    always_ff @(posedge pixel_clk) begin
        if (reset) begin
            valid_s0         <= 1'b0;
            valid_s1         <= 1'b0;
            valid_s2         <= 1'b0;
            screen_x_s0      <= '0;
            screen_y_s0      <= '0;
            world_x_s0       <= '0;
            world_y_s0       <= '0;
            screen_x_s1      <= '0;
            screen_y_s1      <= '0;
            screen_x_s2      <= '0;
            screen_y_s2      <= '0;
            tile_local_x_s1  <= '0;
            tile_local_y_s1  <= '0;
            tile_id_s1       <= '0;
            tile_index_s2    <= '0;
            sprite_index_s2  <= '0;
            sprite_opaque_s2 <= 1'b0;
        end else if (pipeline_advance) begin
            valid_s0    <= pixel_req && pixel_req_ready;
            screen_x_s0 <= pixel_req_x;
            screen_y_s0 <= pixel_req_y;
            world_x_s0  <= pixel_req_x + scroll_x;
            world_y_s0  <= pixel_req_y + scroll_y;

            valid_s1        <= valid_s0;
            screen_x_s1     <= screen_x_s0;
            screen_y_s1     <= screen_y_s0;
            tile_local_x_s1 <= world_x_s0[3:0];
            tile_local_y_s1 <= world_y_s0[3:0];
            tile_id_s1      <= tilemap[tilemap_read_addr];

            valid_s2         <= valid_s1;
            screen_x_s2      <= screen_x_s1;
            screen_y_s2      <= screen_y_s1;
            tile_index_s2    <= tile_graphics[tile_gfx_read_addr];
            sprite_index_s2  <= sprite_index_comb;
            sprite_opaque_s2 <= sprite_opaque_comb;
        end
    end

    // Asynchronous palette lookup avoids another output register.
    always_comb begin
        rgb_valid = valid_s2;
        rgb_x = screen_x_s2;
        rgb_y = screen_y_s2;
        rgb_frame_start = valid_s2 &&
                          (screen_x_s2 == 0) && (screen_y_s2 == 0);
        rgb_frame_end = valid_s2 &&
                        (screen_x_s2 == 1279) && (screen_y_s2 == 719);
        if (!valid_s2)
            rgb565 = 16'h0000;
        else if (sprite_opaque_s2)
            rgb565 = palette[sprite_index_s2];
        else
            rgb565 = palette[tile_index_s2];
    end

    initial begin
        if ((TILE_COUNT < 1) || (TILE_COUNT > 64))
            $error("TILE_COUNT must be between 1 and 64");
        if ((SPRITE_COUNT < 1) || (SPRITE_COUNT > 16))
            $error("SPRITE_COUNT must be between 1 and 16");
    end
endmodule
