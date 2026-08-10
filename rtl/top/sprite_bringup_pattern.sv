// Initializes sprite_engine with a deterministic four-tile test pattern.
// All writes and render_enable are synchronous to pixel_clk.
module sprite_bringup_pattern (
    input  logic        pixel_clk,
    input  logic        reset,

    output logic [10:0] scroll_x,
    output logic [9:0]  scroll_y,

    output logic        tilemap_wr_en,
    output logic [12:0] tilemap_wr_addr,
    output logic [5:0]  tilemap_wr_tile,

    output logic        tile_gfx_wr_en,
    output logic [13:0] tile_gfx_wr_addr,
    output logic [3:0]  tile_gfx_wr_index,

    output logic        sprite_gfx_wr_en,
    output logic [13:0] sprite_gfx_wr_addr,
    output logic [3:0]  sprite_gfx_wr_index,

    output logic        sprite_attr_wr_en,
    output logic [3:0]  sprite_attr_wr_slot,
    output logic [23:0] sprite_attr_wr_data,

    output logic        palette_wr_en,
    output logic [3:0]  palette_wr_index,
    output logic [15:0] palette_wr_rgb565,

    output logic        init_done,
    output logic        render_enable
);
    typedef enum logic [2:0] {
        INIT_PALETTE,
        INIT_SPRITES,
        INIT_SPRITE_GFX,
        INIT_TILE_GFX,
        INIT_TILEMAP,
        INIT_DONE
    } init_state_t;

    init_state_t state;
    logic [3:0]  palette_index;
    logic [3:0]  sprite_slot;
    logic [9:0]  tile_gfx_index;
    logic [9:0]  sprite_gfx_index;
    logic [12:0] tilemap_index;
    logic [1:0]  tile_id;
    logic [7:0]  tile_pixel;

    assign scroll_x = '0;
    assign scroll_y = '0;

    assign tilemap_wr_en = (state == INIT_TILEMAP);
    assign tilemap_wr_addr = tilemap_index;
    // Alternating tile IDs in both X and Y make a 16x16-tile checkerboard.
    assign tilemap_wr_tile = {4'b0000, tilemap_index[7], tilemap_index[0]};

    assign tile_gfx_wr_en = (state == INIT_TILE_GFX);
    assign tile_gfx_wr_addr = {4'b0000, tile_gfx_index};
    assign tile_id = tile_gfx_index[9:8];
    assign tile_pixel = tile_gfx_index[7:0];

    always_comb begin
        case (tile_id)
            2'd0: tile_gfx_wr_index = 4'd1; // Red
            2'd1: tile_gfx_wr_index = 4'd2; // Green
            2'd2: tile_gfx_wr_index = 4'd3; // Blue
            default:
                // Tile 3 contains a white/yellow 8x8 checker.
                tile_gfx_wr_index =
                    tile_pixel[7] ^ tile_pixel[3] ? 4'd4 : 4'd5;
        endcase
    end

    assign sprite_attr_wr_en = (state == INIT_SPRITES);
    assign sprite_attr_wr_slot = sprite_slot;
    assign sprite_attr_wr_data = '0;

    // Slot 0 contains a simple, asymmetric 32x32 test character.  Index 0
    // remains transparent so the moving object also tests sprite blending.
    assign sprite_gfx_wr_en = (state == INIT_SPRITE_GFX);
    assign sprite_gfx_wr_addr = {4'd0, sprite_gfx_index};
    always_comb begin
        if ((sprite_gfx_index[9:5] < 5'd2) ||
            (sprite_gfx_index[9:5] > 5'd29) ||
            (sprite_gfx_index[4:0] < 5'd2) ||
            (sprite_gfx_index[4:0] > 5'd29))
            sprite_gfx_wr_index = 4'd0;
        else if (sprite_gfx_index[9:5] < 5'd10)
            sprite_gfx_wr_index = 4'd5; // Yellow head
        else if (sprite_gfx_index[4:0] < 5'd16)
            sprite_gfx_wr_index = 4'd1; // Red left half
        else
            sprite_gfx_wr_index = 4'd4; // White right half
    end

    assign palette_wr_en = (state == INIT_PALETTE);
    assign palette_wr_index = palette_index;
    always_comb begin
        case (palette_index)
            4'd0: palette_wr_rgb565 = 16'h0000; // Black
            4'd1: palette_wr_rgb565 = 16'hF800; // Red
            4'd2: palette_wr_rgb565 = 16'h07E0; // Green
            4'd3: palette_wr_rgb565 = 16'h001F; // Blue
            4'd4: palette_wr_rgb565 = 16'hFFFF; // White
            4'd5: palette_wr_rgb565 = 16'hFFE0; // Yellow
            default: palette_wr_rgb565 = 16'h0000;
        endcase
    end

    assign init_done = (state == INIT_DONE);
    assign render_enable = init_done;

    always_ff @(posedge pixel_clk) begin
        if (reset) begin
            state          <= INIT_PALETTE;
            palette_index  <= '0;
            sprite_slot    <= '0;
            tile_gfx_index <= '0;
            sprite_gfx_index <= '0;
            tilemap_index  <= '0;
        end else begin
            case (state)
                INIT_PALETTE: begin
                    if (palette_index == 4'd15) begin
                        palette_index <= '0;
                        state <= INIT_SPRITES;
                    end else begin
                        palette_index <= palette_index + 1'b1;
                    end
                end

                INIT_SPRITES: begin
                    if (sprite_slot == 4'd15) begin
                        sprite_slot <= '0;
                        state <= INIT_SPRITE_GFX;
                    end else begin
                        sprite_slot <= sprite_slot + 1'b1;
                    end
                end

                INIT_SPRITE_GFX: begin
                    if (sprite_gfx_index == 10'd1023) begin
                        sprite_gfx_index <= '0;
                        state <= INIT_TILE_GFX;
                    end else begin
                        sprite_gfx_index <= sprite_gfx_index + 1'b1;
                    end
                end

                INIT_TILE_GFX: begin
                    if (tile_gfx_index == 10'd1023) begin
                        tile_gfx_index <= '0;
                        state <= INIT_TILEMAP;
                    end else begin
                        tile_gfx_index <= tile_gfx_index + 1'b1;
                    end
                end

                INIT_TILEMAP: begin
                    if (tilemap_index == 13'd8191) begin
                        tilemap_index <= '0;
                        state <= INIT_DONE;
                    end else begin
                        tilemap_index <= tilemap_index + 1'b1;
                    end
                end

                default: state <= INIT_DONE;
            endcase
        end
    end
endmodule
