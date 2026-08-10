// Converts the AXI DMA MM2S stream into sprite-engine memory writes.
//
// Place an AXI4-Stream Clock Converter between AXI DMA and this module so all
// ports here are synchronous to pixel_clk. Configure the stream width to
// 256 bits and enable TKEEP/TLAST.
module sprite_asset_unpacker (
    input  logic         pixel_clk,
    input  logic         reset,

    input  logic [255:0] s_axis_tdata,
    input  logic [31:0]  s_axis_tkeep,
    input  logic         s_axis_tlast,
    input  logic         s_axis_tvalid,
    output logic         s_axis_tready,

    // Must be programmed before starting AXI DMA and held until done.
    input  logic [1:0]   dest_kind,
    input  logic [15:0]  dest_addr,
    input  logic         clear_status,
    output logic         busy,
    output logic         done,
    output logic         error,

    output logic         tilemap_wr_en,
    output logic [12:0]  tilemap_wr_addr,
    output logic [5:0]   tilemap_wr_tile,
    output logic         tile_gfx_wr_en,
    output logic [13:0]  tile_gfx_wr_addr,
    output logic [3:0]   tile_gfx_wr_index,
    output logic         sprite_gfx_wr_en,
    output logic [13:0]  sprite_gfx_wr_addr,
    output logic [3:0]   sprite_gfx_wr_index,
    output logic         palette_wr_en,
    output logic [3:0]   palette_wr_index,
    output logic [15:0]  palette_wr_rgb565
);
    logic [255:0] data_shift;
    logic [31:0] keep_shift;
    logic word_last;
    logic word_loaded;
    logic [1:0] active_kind;
    logic [15:0] active_addr;
    logic destination_valid;

    always_comb begin
        case (active_kind)
            2'd0: destination_valid = active_addr < 8192;
            2'd1: destination_valid = active_addr < 16384;
            2'd2: destination_valid = active_addr < 16384;
            default: destination_valid = active_addr < 16;
        endcase
    end

    assign s_axis_tready = !word_loaded;

    always_ff @(posedge pixel_clk) begin
        if (reset) begin
            data_shift          <= '0;
            keep_shift          <= '0;
            word_last           <= 1'b0;
            word_loaded         <= 1'b0;
            active_kind         <= '0;
            active_addr         <= '0;
            busy                <= 1'b0;
            done                <= 1'b0;
            error               <= 1'b0;
            tilemap_wr_en       <= 1'b0;
            tilemap_wr_addr     <= '0;
            tilemap_wr_tile     <= '0;
            tile_gfx_wr_en      <= 1'b0;
            tile_gfx_wr_addr    <= '0;
            tile_gfx_wr_index   <= '0;
            sprite_gfx_wr_en    <= 1'b0;
            sprite_gfx_wr_addr  <= '0;
            sprite_gfx_wr_index <= '0;
            palette_wr_en       <= 1'b0;
            palette_wr_index    <= '0;
            palette_wr_rgb565   <= '0;
        end else begin
            tilemap_wr_en    <= 1'b0;
            tile_gfx_wr_en   <= 1'b0;
            sprite_gfx_wr_en <= 1'b0;
            palette_wr_en    <= 1'b0;

            if (clear_status) begin
                done  <= 1'b0;
                error <= 1'b0;
            end

            if (s_axis_tvalid && s_axis_tready) begin
                data_shift  <= s_axis_tdata;
                keep_shift  <= s_axis_tkeep;
                word_last   <= s_axis_tlast;
                word_loaded <= 1'b1;

                if (!busy) begin
                    active_kind <= dest_kind;
                    active_addr <= dest_addr;
                    busy  <= 1'b1;
                    done  <= 1'b0;
                    error <= 1'b0;
                end
            end else if (word_loaded) begin
                if (keep_shift == 0) begin
                    word_loaded <= 1'b0;
                    if (word_last) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                end else if (!keep_shift[0]) begin
                    // AXI DMA normally produces contiguous low-byte TKEEP.
                    // Consume holes defensively and report malformed input.
                    data_shift <= data_shift >> 8;
                    keep_shift <= keep_shift >> 1;
                    error <= 1'b1;
                end else if ((active_kind == 2'd3) && !keep_shift[1]) begin
                    // RGB565 palette entries require complete 16-bit items.
                    data_shift <= data_shift >> 8;
                    keep_shift <= keep_shift >> 1;
                    error <= 1'b1;
                end else begin
                    if (!destination_valid) begin
                        error <= 1'b1;
                    end else begin
                        case (active_kind)
                            2'd0: begin
                                tilemap_wr_en   <= 1'b1;
                                tilemap_wr_addr <= active_addr[12:0];
                                tilemap_wr_tile <= data_shift[5:0];
                            end
                            2'd1: begin
                                tile_gfx_wr_en    <= 1'b1;
                                tile_gfx_wr_addr  <= active_addr[13:0];
                                tile_gfx_wr_index <= data_shift[3:0];
                            end
                            2'd2: begin
                                sprite_gfx_wr_en    <= 1'b1;
                                sprite_gfx_wr_addr  <= active_addr[13:0];
                                sprite_gfx_wr_index <= data_shift[3:0];
                            end
                            default: begin
                                palette_wr_en     <= 1'b1;
                                palette_wr_index  <= active_addr[3:0];
                                palette_wr_rgb565 <= data_shift[15:0];
                            end
                        endcase
                    end

                    active_addr <= active_addr + 1'b1;
                    if (active_kind == 2'd3) begin
                        data_shift <= data_shift >> 16;
                        keep_shift <= keep_shift >> 2;
                    end else begin
                        data_shift <= data_shift >> 8;
                        keep_shift <= keep_shift >> 1;
                    end
                end
            end
        end
    end
endmodule
