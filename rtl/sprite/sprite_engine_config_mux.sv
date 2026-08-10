// Combines AXI-Lite control writes and bulk asset-loader writes.
// Software palette writes are held by sprite_engine_axi_lite while DMA is
// busy, so loader priority cannot discard a control-plane palette update.
module sprite_engine_config_mux (
    input  logic        loader_tilemap_wr_en,
    input  logic [12:0] loader_tilemap_wr_addr,
    input  logic [5:0]  loader_tilemap_wr_tile,
    input  logic        loader_tile_gfx_wr_en,
    input  logic [13:0] loader_tile_gfx_wr_addr,
    input  logic [3:0]  loader_tile_gfx_wr_index,
    input  logic        loader_sprite_gfx_wr_en,
    input  logic [13:0] loader_sprite_gfx_wr_addr,
    input  logic [3:0]  loader_sprite_gfx_wr_index,
    input  logic        loader_palette_wr_en,
    input  logic [3:0]  loader_palette_wr_index,
    input  logic [15:0] loader_palette_wr_rgb565,

    input  logic        control_sprite_attr_wr_en,
    input  logic [3:0]  control_sprite_attr_wr_slot,
    input  logic [23:0] control_sprite_attr_wr_data,
    input  logic        control_palette_wr_en,
    input  logic [3:0]  control_palette_wr_index,
    input  logic [15:0] control_palette_wr_rgb565,

    output logic        engine_tilemap_wr_en,
    output logic [12:0] engine_tilemap_wr_addr,
    output logic [5:0]  engine_tilemap_wr_tile,
    output logic        engine_tile_gfx_wr_en,
    output logic [13:0] engine_tile_gfx_wr_addr,
    output logic [3:0]  engine_tile_gfx_wr_index,
    output logic        engine_sprite_gfx_wr_en,
    output logic [13:0] engine_sprite_gfx_wr_addr,
    output logic [3:0]  engine_sprite_gfx_wr_index,
    output logic        engine_sprite_attr_wr_en,
    output logic [3:0]  engine_sprite_attr_wr_slot,
    output logic [23:0] engine_sprite_attr_wr_data,
    output logic        engine_palette_wr_en,
    output logic [3:0]  engine_palette_wr_index,
    output logic [15:0] engine_palette_wr_rgb565
);
    always_comb begin
        engine_tilemap_wr_en     = loader_tilemap_wr_en;
        engine_tilemap_wr_addr   = loader_tilemap_wr_addr;
        engine_tilemap_wr_tile   = loader_tilemap_wr_tile;
        engine_tile_gfx_wr_en    = loader_tile_gfx_wr_en;
        engine_tile_gfx_wr_addr  = loader_tile_gfx_wr_addr;
        engine_tile_gfx_wr_index = loader_tile_gfx_wr_index;
        engine_sprite_gfx_wr_en    = loader_sprite_gfx_wr_en;
        engine_sprite_gfx_wr_addr  = loader_sprite_gfx_wr_addr;
        engine_sprite_gfx_wr_index = loader_sprite_gfx_wr_index;
        engine_sprite_attr_wr_en   = control_sprite_attr_wr_en;
        engine_sprite_attr_wr_slot = control_sprite_attr_wr_slot;
        engine_sprite_attr_wr_data = control_sprite_attr_wr_data;

        if (loader_palette_wr_en) begin
            engine_palette_wr_en     = 1'b1;
            engine_palette_wr_index  = loader_palette_wr_index;
            engine_palette_wr_rgb565 = loader_palette_wr_rgb565;
        end else begin
            engine_palette_wr_en     = control_palette_wr_en;
            engine_palette_wr_index  = control_palette_wr_index;
            engine_palette_wr_rgb565 = control_palette_wr_rgb565;
        end
    end
endmodule
