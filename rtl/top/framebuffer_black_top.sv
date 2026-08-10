// First complete framebuffer display path for the CF7A100B:
// MicroBlaze clears DDR3, AXI VDMA MM2S reads RGB565, an asynchronous FIFO
// crosses into the 720p pixel clock domain, and HDMI_B outputs the image.
module framebuffer_black_top (
    input  logic        sys_clk_i,
    input  logic        sys_rst_n,

    inout  wire [31:0]  ddr3_dq,
    inout  wire [3:0]   ddr3_dqs_n,
    inout  wire [3:0]   ddr3_dqs_p,
    output wire [13:0]  ddr3_addr,
    output wire [2:0]   ddr3_ba,
    output wire         ddr3_ras_n,
    output wire         ddr3_cas_n,
    output wire         ddr3_we_n,
    output wire         ddr3_reset_n,
    output wire [0:0]   ddr3_ck_p,
    output wire [0:0]   ddr3_ck_n,
    output wire [0:0]   ddr3_cke,
    output wire [0:0]   ddr3_cs_n,
    output wire [3:0]   ddr3_dm,
    output wire [0:0]   ddr3_odt,

    input  logic        uart_rxd,
    output logic        uart_txd,

    input  wire         sd_miso,
    output wire         sd_mosi,
    output wire         sd_clk,
    output wire         sd_cs,

    output logic        tmds_clk_p,
    output logic        tmds_clk_n,
    output logic [2:0]  tmds_data_p,
    output logic [2:0]  tmds_data_n,
    output logic [3:0]  led
);
    logic sys_clk_ibuf;
    logic sys_clk_buf;
    logic clk_ref_fb;
    logic clk_ref_fb_buf;
    logic clk_ref_200_unbuf;
    logic clk_ref_200;
    logic clk_spi_unbuf;
    logic clk_spi;
    logic clk_ref_locked;

    logic pixel_clk;
    logic pixel_clk_5x;
    logic hdmi_locked;

    logic ui_clk;
    logic ui_clk_sync_rst;
    logic init_calib_complete;
    logic mig_mmcm_locked;
    logic mig_aresetn;
    logic [11:0] device_temp;

    logic [15:0] axis_tdata;
    logic [1:0]  axis_tkeep;
    logic        axis_tlast;
    logic        axis_tready;
    logic [0:0]  axis_tuser;
    logic        axis_tvalid;

    logic [15:0] s2mm_tdata;
    logic [1:0]  s2mm_tkeep;
    logic        s2mm_tlast;
    logic        s2mm_tready;
    logic        s2mm_tuser;
    logic        s2mm_tvalid;

    logic        render_pixel_req;
    logic [10:0] render_pixel_req_x;
    logic [9:0]  render_pixel_req_y;
    logic        render_pixel_req_ready;
    logic [15:0] renderer_rgb565;
    logic [15:0] rendered_rgb565;
    logic        rendered_rgb_valid;
    logic        rendered_rgb_ready;
    logic [10:0] rendered_rgb_x;
    logic [9:0]  rendered_rgb_y;
    logic        render_frame_active;
    logic        render_frame_done;
    logic        render_init_done;
    logic        render_pattern_ready;
    logic [31:0] render_control_gpio;
    logic [31:0] render_control_pixel;
    logic [31:0] asset_command_gpio;
    logic [31:0] asset_command_pixel;
    logic        asset_ack_pixel;
    logic        asset_ack_ui;
    logic [1:0]  asset_settle_count;
    logic        render_enable;
    logic [10:0] render_scroll_x;
    logic [9:0]  render_scroll_y;
    logic [10:0] pattern_scroll_x;
    logic [9:0]  pattern_scroll_y;
    logic [10:0] dynamic_scroll_x;
    logic        render_tilemap_wr_en;
    logic [12:0] render_tilemap_wr_addr;
    logic [5:0]  render_tilemap_wr_tile;
    logic        render_tile_gfx_wr_en;
    logic [13:0] render_tile_gfx_wr_addr;
    logic [3:0]  render_tile_gfx_wr_index;
    logic        render_sprite_attr_wr_en;
    logic [3:0]  render_sprite_attr_wr_slot;
    logic [23:0] render_sprite_attr_wr_data;
    logic        pattern_sprite_attr_wr_en;
    logic [3:0]  pattern_sprite_attr_wr_slot;
    logic [23:0] pattern_sprite_attr_wr_data;
    logic        dynamic_sprite_attr_wr_en;
    logic [3:0]  dynamic_sprite_attr_wr_slot;
    logic [23:0] dynamic_sprite_attr_wr_data;
    logic [2:0]  dynamic_attr_write_index;
    logic [31:0] render_control_frame;
    logic [23:0] enemy_sprite_attr [0:3];
    logic [23:0] enemy_sprite_attr_frame [0:3];
    logic [23:0] enemy_sprite_attr_aligned [0:3];
    logic [10:0] enemy_frame_camera_x;
    logic [11:0] enemy_frame_camera_right;
    integer      enemy_align_index;
    logic        render_sprite_gfx_wr_en;
    logic [13:0] render_sprite_gfx_wr_addr;
    logic [3:0]  render_sprite_gfx_wr_index;
    logic        render_palette_wr_en;
    logic [3:0]  render_palette_wr_index;
    logic [15:0] render_palette_wr_rgb565;
    logic        pattern_tilemap_wr_en;
    logic [12:0] pattern_tilemap_wr_addr;
    logic [5:0]  pattern_tilemap_wr_tile;
    logic        pattern_tile_gfx_wr_en;
    logic [13:0] pattern_tile_gfx_wr_addr;
    logic [3:0]  pattern_tile_gfx_wr_index;
    logic        pattern_sprite_gfx_wr_en;
    logic [13:0] pattern_sprite_gfx_wr_addr;
    logic [3:0]  pattern_sprite_gfx_wr_index;
    logic        pattern_palette_wr_en;
    logic [3:0]  pattern_palette_wr_index;
    logic [15:0] pattern_palette_wr_rgb565;
    logic        loader_tilemap_wr_en;
    logic [12:0] loader_tilemap_wr_addr;
    logic [5:0]  loader_tilemap_wr_tile;
    logic        loader_tile_gfx_wr_en;
    logic [13:0] loader_tile_gfx_wr_addr;
    logic [3:0]  loader_tile_gfx_wr_index;
    logic        loader_sprite_gfx_wr_en;
    logic [13:0] loader_sprite_gfx_wr_addr;
    logic [3:0]  loader_sprite_gfx_wr_index;
    logic        loader_palette_wr_en;
    logic [3:0]  loader_palette_wr_index;
    logic [15:0] loader_palette_wr_rgb565;

    logic [31:0]  axi_araddr;
    logic [1:0]   axi_arburst;
    logic [3:0]   axi_arcache;
    logic [7:0]   axi_arlen;
    logic [0:0]   axi_arlock;
    logic [2:0]   axi_arprot;
    logic [3:0]   axi_arqos;
    logic         axi_arready;
    logic [2:0]   axi_arsize;
    logic         axi_arvalid;
    logic [31:0]  axi_awaddr;
    logic [1:0]   axi_awburst;
    logic [3:0]   axi_awcache;
    logic [7:0]   axi_awlen;
    logic [0:0]   axi_awlock;
    logic [2:0]   axi_awprot;
    logic [3:0]   axi_awqos;
    logic         axi_awready;
    logic [2:0]   axi_awsize;
    logic         axi_awvalid;
    logic         axi_bready;
    logic [1:0]   axi_bresp;
    logic         axi_bvalid;
    logic [255:0] axi_rdata;
    logic         axi_rlast;
    logic         axi_rready;
    logic [1:0]   axi_rresp;
    logic         axi_rvalid;
    logic [255:0] axi_wdata;
    logic         axi_wlast;
    logic         axi_wready;
    logic [31:0]  axi_wstrb;
    logic         axi_wvalid;

    logic [15:0] fifo_rgb565;
    logic [15:0] hud_rgb565;
    logic [10:0] hdmi_pixel_x;
    logic [9:0]  hdmi_pixel_y;
    logic [5:0]  hud_coin_count;
    logic [1:0]  hud_health;
    logic        hud_goal_reached;
    logic        hud_power_active;
    logic        hud_visible;
    logic        fifo_pixel_valid;
    logic        fifo_full;
    logic        fifo_prog_full;
    logic        fifo_empty;
    logic        fifo_prog_empty;
    logic        fifo_prefilled;
    logic [13:0] fifo_wr_data_count;
    logic        fifo_underflow;
    logic        underflow_sticky;
    logic        stream_error_sticky;
    logic        pixel_req;
    logic        frame_start;
    logic        reset_request;
    logic        axis_reset;
    logic        pixel_reset;
    logic        video_reset;
    logic [26:0] ui_heartbeat;

    IBUF sys_clk_input_buffer (
        .I (sys_clk_i),
        .O (sys_clk_ibuf)
    );

    BUFG sys_clk_global_buffer (
        .I (sys_clk_ibuf),
        .O (sys_clk_buf)
    );

    // 50 MHz -> 800 MHz VCO -> 200 MHz MIG IODELAY reference.
    MMCME2_BASE #(
        .BANDWIDTH        ("OPTIMIZED"),
        .CLKIN1_PERIOD    (20.000),
        .DIVCLK_DIVIDE    (1),
        .CLKFBOUT_MULT_F  (16.000),
        .CLKOUT0_DIVIDE_F (4.000),
        .CLKOUT1_DIVIDE   (128),
        .STARTUP_WAIT     ("FALSE")
    ) ref_clock_mmcm (
        .CLKIN1   (sys_clk_buf),
        .CLKFBIN  (clk_ref_fb_buf),
        .RST      (~sys_rst_n),
        .PWRDWN   (1'b0),
        .CLKFBOUT (clk_ref_fb),
        .CLKOUT0  (clk_ref_200_unbuf),
        .CLKOUT1  (clk_spi_unbuf),
        .LOCKED   (clk_ref_locked)
    );

    BUFG ref_feedback_buffer (
        .I (clk_ref_fb),
        .O (clk_ref_fb_buf)
    );

    BUFG ref_clock_global_buffer (
        .I (clk_ref_200_unbuf),
        .O (clk_ref_200)
    );

    // 800 MHz MMCM VCO / 128 = 6.25 MHz. AXI Quad SPI divides this by 16,
    // keeping SD initialization SCK at 390.625 kHz.
    BUFG spi_clock_global_buffer (
        .I (clk_spi_unbuf),
        .O (clk_spi)
    );

    // This wizard is configured for "No buffer": sys_clk_buf is already a
    // global clock. Its two outputs retain the verified exact 1:5 ratio.
    clk_wiz_hdmi_framebuffer hdmi_clocks (
        .clk_out1 (pixel_clk),
        .clk_out2 (pixel_clk_5x),
        .reset    (~sys_rst_n),
        .locked   (hdmi_locked),
        .clk_in1  (sys_clk_buf)
    );

    always_ff @(posedge ui_clk)
        mig_aresetn <= ~ui_clk_sync_rst;

    always_ff @(posedge ui_clk) begin
        if (ui_clk_sync_rst)
            ui_heartbeat <= '0;
        else
            ui_heartbeat <= ui_heartbeat + 1'b1;
    end

    framebuffer_black_bd_wrapper subsystem (
        .MM2S_AXIS_tdata     (axis_tdata),
        .MM2S_AXIS_tkeep     (axis_tkeep),
        .MM2S_AXIS_tlast     (axis_tlast),
        .MM2S_AXIS_tready    (axis_tready),
        .MM2S_AXIS_tuser     (axis_tuser),
        .MM2S_AXIS_tvalid    (axis_tvalid),
        .S2MM_AXIS_tdata     (s2mm_tdata),
        .S2MM_AXIS_tkeep     (s2mm_tkeep),
        .S2MM_AXIS_tlast     (s2mm_tlast),
        .S2MM_AXIS_tready    (s2mm_tready),
        .S2MM_AXIS_tuser     (s2mm_tuser),
        .S2MM_AXIS_tvalid    (s2mm_tvalid),
        .M_AXI_DDR_araddr    (axi_araddr),
        .M_AXI_DDR_arburst   (axi_arburst),
        .M_AXI_DDR_arcache   (axi_arcache),
        .M_AXI_DDR_arlen     (axi_arlen),
        .M_AXI_DDR_arlock    (axi_arlock),
        .M_AXI_DDR_arprot    (axi_arprot),
        .M_AXI_DDR_arqos     (axi_arqos),
        .M_AXI_DDR_arready   (axi_arready),
        .M_AXI_DDR_arsize    (axi_arsize),
        .M_AXI_DDR_arvalid   (axi_arvalid),
        .M_AXI_DDR_awaddr    (axi_awaddr),
        .M_AXI_DDR_awburst   (axi_awburst),
        .M_AXI_DDR_awcache   (axi_awcache),
        .M_AXI_DDR_awlen     (axi_awlen),
        .M_AXI_DDR_awlock    (axi_awlock),
        .M_AXI_DDR_awprot    (axi_awprot),
        .M_AXI_DDR_awqos     (axi_awqos),
        .M_AXI_DDR_awready   (axi_awready),
        .M_AXI_DDR_awsize    (axi_awsize),
        .M_AXI_DDR_awvalid   (axi_awvalid),
        .M_AXI_DDR_bready    (axi_bready),
        .M_AXI_DDR_bresp     (axi_bresp),
        .M_AXI_DDR_bvalid    (axi_bvalid),
        .M_AXI_DDR_rdata     (axi_rdata),
        .M_AXI_DDR_rlast     (axi_rlast),
        .M_AXI_DDR_rready    (axi_rready),
        .M_AXI_DDR_rresp     (axi_rresp),
        .M_AXI_DDR_rvalid    (axi_rvalid),
        .M_AXI_DDR_wdata     (axi_wdata),
        .M_AXI_DDR_wlast     (axi_wlast),
        .M_AXI_DDR_wready    (axi_wready),
        .M_AXI_DDR_wstrb     (axi_wstrb),
        .M_AXI_DDR_wvalid    (axi_wvalid),
        .init_calib_complete (init_calib_complete),
        .asset_command       (asset_command_gpio),
        .asset_ack           (asset_ack_ui),
        .render_control      (render_control_gpio),
        .sd_miso             (sd_miso),
        .sd_mosi             (sd_mosi),
        .sd_clk              (sd_clk),
        .sd_cs               (sd_cs),
        .uart_rxd            (uart_rxd),
        .uart_txd            (uart_txd),
        .s2mm_axis_aclk      (pixel_clk),
        .spi_axi_clk         (clk_spi),
        .ui_clk              (ui_clk),
        .ui_clk_sync_rst     (ui_clk_sync_rst)
    );

    mig_7series_0 mig (
        .ddr3_addr           (ddr3_addr),
        .ddr3_ba             (ddr3_ba),
        .ddr3_cas_n          (ddr3_cas_n),
        .ddr3_ck_n           (ddr3_ck_n),
        .ddr3_ck_p           (ddr3_ck_p),
        .ddr3_cke            (ddr3_cke),
        .ddr3_ras_n          (ddr3_ras_n),
        .ddr3_reset_n        (ddr3_reset_n),
        .ddr3_we_n           (ddr3_we_n),
        .ddr3_dq             (ddr3_dq),
        .ddr3_dqs_n          (ddr3_dqs_n),
        .ddr3_dqs_p          (ddr3_dqs_p),
        .init_calib_complete (init_calib_complete),
        .ddr3_cs_n           (ddr3_cs_n),
        .ddr3_dm             (ddr3_dm),
        .ddr3_odt            (ddr3_odt),
        .ui_clk              (ui_clk),
        .ui_clk_sync_rst     (ui_clk_sync_rst),
        .ui_addn_clk_0       (),
        .ui_addn_clk_1       (),
        .ui_addn_clk_2       (),
        .ui_addn_clk_3       (),
        .ui_addn_clk_4       (),
        .mmcm_locked         (mig_mmcm_locked),
        .aresetn             (mig_aresetn),
        .app_sr_req          (1'b0),
        .app_ref_req         (1'b0),
        .app_zq_req          (1'b0),
        .app_sr_active       (),
        .app_ref_ack         (),
        .app_zq_ack          (),
        .device_temp         (device_temp),

        .s_axi_awid          (4'd0),
        .s_axi_awaddr        (axi_awaddr[28:0]),
        .s_axi_awlen         (axi_awlen),
        .s_axi_awsize        (axi_awsize),
        .s_axi_awburst       (axi_awburst),
        .s_axi_awlock        (axi_awlock),
        .s_axi_awcache       (axi_awcache),
        .s_axi_awprot        (axi_awprot),
        .s_axi_awqos         (axi_awqos),
        .s_axi_awvalid       (axi_awvalid),
        .s_axi_awready       (axi_awready),
        .s_axi_wdata         (axi_wdata),
        .s_axi_wstrb         (axi_wstrb),
        .s_axi_wlast         (axi_wlast),
        .s_axi_wvalid        (axi_wvalid),
        .s_axi_wready        (axi_wready),
        .s_axi_bid           (),
        .s_axi_bresp         (axi_bresp),
        .s_axi_bvalid        (axi_bvalid),
        .s_axi_bready        (axi_bready),
        .s_axi_arid          (4'd0),
        .s_axi_araddr        (axi_araddr[28:0]),
        .s_axi_arlen         (axi_arlen),
        .s_axi_arsize        (axi_arsize),
        .s_axi_arburst       (axi_arburst),
        .s_axi_arlock        (axi_arlock),
        .s_axi_arcache       (axi_arcache),
        .s_axi_arprot        (axi_arprot),
        .s_axi_arqos         (axi_arqos),
        .s_axi_arvalid       (axi_arvalid),
        .s_axi_arready       (axi_arready),
        .s_axi_rid           (),
        .s_axi_rdata         (axi_rdata),
        .s_axi_rresp         (axi_rresp),
        .s_axi_rlast         (axi_rlast),
        .s_axi_rvalid        (axi_rvalid),
        .s_axi_rready        (axi_rready),
        .sys_clk_i           (sys_clk_buf),
        .clk_ref_i           (clk_ref_200),
        .sys_rst             (sys_rst_n & clk_ref_locked)
    );

    assign reset_request = !sys_rst_n || !init_calib_complete ||
                           !hdmi_locked;

    // Each clock domain gets asynchronous assertion and synchronous release.
    // XPM also provides the required recovery/removal timing exceptions.
    xpm_cdc_async_rst #(
        .DEST_SYNC_FF    (4),
        .INIT_SYNC_FF    (0),
        .RST_ACTIVE_HIGH (1)
    ) axis_reset_cdc (
        .src_arst  (reset_request),
        .dest_clk  (ui_clk),
        .dest_arst (axis_reset)
    );

    xpm_cdc_async_rst #(
        .DEST_SYNC_FF    (4),
        .INIT_SYNC_FF    (0),
        .RST_ACTIVE_HIGH (1)
    ) pixel_reset_cdc (
        .src_arst  (reset_request),
        .dest_clk  (pixel_clk),
        .dest_arst (pixel_reset)
    );

    // Software enables the source only after S2MM has been fully configured.
    // The stream module observes enable in pixel_clk and always begins at SOF.
    xpm_cdc_array_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0),
        .WIDTH          (32)
    ) render_control_cdc (
        .src_clk  (ui_clk),
        .src_in   (render_control_gpio),
        .dest_clk (pixel_clk),
        .dest_out (render_control_pixel)
    );

    assign render_enable = render_control_pixel[0];

    // The command bus remains stable until the pixel domain mirrors its
    // sequence bit on asset_ack. This bundled-data handshake safely carries
    // one resource write at a time without requiring an AXI clock converter.
    xpm_cdc_array_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0),
        .WIDTH          (32)
    ) asset_command_cdc (
        .src_clk  (ui_clk),
        .src_in   (asset_command_gpio),
        .dest_clk (pixel_clk),
        .dest_out (asset_command_pixel)
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0)
    ) asset_ack_cdc (
        .src_clk  (pixel_clk),
        .src_in   (asset_ack_pixel),
        .dest_clk (ui_clk),
        .dest_out (asset_ack_ui)
    );

    // Command format:
    // [31] sequence toggle, [30:29] destination kind.
    // Map/tile/sprite: [28:15] address, [7:0] indexed pixel/tile.
    // Palette: [28:25] index, [24:9] little-endian RGB565 value.
    always_ff @(posedge pixel_clk) begin
        if (pixel_reset) begin
            asset_ack_pixel             <= 1'b0;
            asset_settle_count           <= '0;
            loader_tilemap_wr_en         <= 1'b0;
            loader_tilemap_wr_addr       <= '0;
            loader_tilemap_wr_tile       <= '0;
            loader_tile_gfx_wr_en        <= 1'b0;
            loader_tile_gfx_wr_addr      <= '0;
            loader_tile_gfx_wr_index     <= '0;
            loader_sprite_gfx_wr_en      <= 1'b0;
            loader_sprite_gfx_wr_addr    <= '0;
            loader_sprite_gfx_wr_index   <= '0;
            loader_palette_wr_en         <= 1'b0;
            loader_palette_wr_index      <= '0;
            loader_palette_wr_rgb565     <= '0;
            hud_coin_count               <= '0;
            hud_health                   <= 2'd3;
            hud_goal_reached             <= 1'b0;
            hud_power_active             <= 1'b0;
            hud_visible                  <= 1'b0;
            enemy_sprite_attr[0]          <= '0;
            enemy_sprite_attr[1]          <= '0;
            enemy_sprite_attr[2]          <= '0;
            enemy_sprite_attr[3]          <= '0;
        end else begin
            loader_tilemap_wr_en    <= 1'b0;
            loader_tile_gfx_wr_en   <= 1'b0;
            loader_sprite_gfx_wr_en <= 1'b0;
            loader_palette_wr_en    <= 1'b0;

            // The GPIO command is bundled data: software holds all 32 bits
            // until the sequence toggle is acknowledged.  The individual
            // bits still pass through independent synchronizers, however, so
            // the sequence bit can become visible one destination cycle
            // before one of the payload bits.  Wait two complete pixel-clock
            // cycles after detecting a new sequence before sampling the bus.
            // This prevents rare tile/palette corruption and one-frame enemy
            // coordinate jumps after many thousands of commands.
            if (asset_settle_count != 0) begin
                asset_settle_count <= asset_settle_count - 1'b1;
            end else if (asset_command_pixel[31] != asset_ack_pixel) begin
                asset_settle_count <= 2'd2;
            end

            if (asset_settle_count == 1) begin
                case (asset_command_pixel[30:29])
                    2'd0: begin
                        loader_tilemap_wr_en   <= 1'b1;
                        loader_tilemap_wr_addr <= asset_command_pixel[27:15];
                        loader_tilemap_wr_tile <= asset_command_pixel[5:0];
                    end
                    2'd1: begin
                        loader_tile_gfx_wr_en    <= 1'b1;
                        loader_tile_gfx_wr_addr  <= asset_command_pixel[28:15];
                        loader_tile_gfx_wr_index <= asset_command_pixel[3:0];
                    end
                    2'd2: begin
                        loader_sprite_gfx_wr_en    <= 1'b1;
                        loader_sprite_gfx_wr_addr  <= asset_command_pixel[28:15];
                        loader_sprite_gfx_wr_index <= asset_command_pixel[3:0];
                    end
                    default: begin
                        // Palette commands have zero in bits [8:0].  The
                        // nonzero magic value reserves this same reliable
                        // handshake for slowly-changing HUD state.
                        if (asset_command_pixel[8:0] == 9'h155) begin
                            hud_coin_count   <= asset_command_pixel[14:9];
                            hud_goal_reached <= asset_command_pixel[15];
                            hud_health       <= asset_command_pixel[17:16];
                            hud_power_active <= asset_command_pixel[18];
                            hud_visible      <= asset_command_pixel[19];
                        end else if (asset_command_pixel[3:0] == 4'hB) begin
                            // Full-pixel enemy command: world X[28:18], Y[17:8],
                            // zero-based enemy slot[7:6], enable[5], flip[4].
                            case (asset_command_pixel[7:6])
                                2'd0: enemy_sprite_attr[0] <= {
                                    1'b0, asset_command_pixel[4],
                                    asset_command_pixel[17:8],
                                    asset_command_pixel[28:18],
                                    asset_command_pixel[5]};
                                2'd1: enemy_sprite_attr[1] <= {
                                    1'b0, asset_command_pixel[4],
                                    asset_command_pixel[17:8],
                                    asset_command_pixel[28:18],
                                    asset_command_pixel[5]};
                                2'd2: enemy_sprite_attr[2] <= {
                                    1'b0, asset_command_pixel[4],
                                    asset_command_pixel[17:8],
                                    asset_command_pixel[28:18],
                                    asset_command_pixel[5]};
                                default: enemy_sprite_attr[3] <= {
                                    1'b0, asset_command_pixel[4],
                                    asset_command_pixel[17:8],
                                    asset_command_pixel[28:18],
                                    asset_command_pixel[5]};
                            endcase
                        end else begin
                            loader_palette_wr_en <= 1'b1;
                            loader_palette_wr_index <=
                                asset_command_pixel[28:25];
                            loader_palette_wr_rgb565 <=
                                asset_command_pixel[24:9];
                        end
                    end
                endcase
                asset_ack_pixel <= asset_command_pixel[31];
            end
        end
    end

    // Keep enemy positions in world coordinates until the exact render-frame
    // boundary.  Camera control and enemy commands cross into this clock
    // domain independently; converting to screen coordinates earlier can
    // combine a new camera with old enemy coordinates for one frame, making
    // every visible enemy jump together.  This combinational view uses one
    // camera snapshot for all four enemies and is registered atomically below.
    always_comb begin
        enemy_frame_camera_x = {
            1'b0, render_control_pixel[29:21], 1'b0
        };
        enemy_frame_camera_right =
            {1'b0, enemy_frame_camera_x} + 12'd1280;
        for (enemy_align_index = 0; enemy_align_index < 4;
             enemy_align_index = enemy_align_index + 1) begin
            enemy_sprite_attr_aligned[enemy_align_index] = {
                enemy_sprite_attr[enemy_align_index][23:12],
                11'd0,
                1'b0
            };
            if (enemy_sprite_attr[enemy_align_index][0] &&
                ({1'b0, enemy_sprite_attr[enemy_align_index][11:1]} >=
                 {1'b0, enemy_frame_camera_x}) &&
                ({1'b0, enemy_sprite_attr[enemy_align_index][11:1]} <
                 enemy_frame_camera_right)) begin
                enemy_sprite_attr_aligned[enemy_align_index][11:1] =
                    enemy_sprite_attr[enemy_align_index][11:1] -
                    enemy_frame_camera_x;
                enemy_sprite_attr_aligned[enemy_align_index][0] = 1'b1;
            end
        end
    end

    // Sample the slowly-changing GPIO command only at a completed render
    // frame.  Sprite attributes therefore never change halfway through a
    // framebuffer, making tearing or frame ownership faults visible instead
    // of hiding them behind intra-frame motion.
    always_ff @(posedge pixel_clk) begin
        if (pixel_reset) begin
            dynamic_sprite_attr_wr_en   <= 1'b0;
            dynamic_sprite_attr_wr_slot <= '0;
            dynamic_sprite_attr_wr_data <= '0;
            dynamic_attr_write_index    <= '0;
            render_control_frame        <= '0;
            enemy_sprite_attr_frame[0]  <= '0;
            enemy_sprite_attr_frame[1]  <= '0;
            enemy_sprite_attr_frame[2]  <= '0;
            enemy_sprite_attr_frame[3]  <= '0;
            dynamic_scroll_x            <= '0;
        end else begin
            dynamic_sprite_attr_wr_en <= 1'b0;
            if (dynamic_attr_write_index != 0) begin
                dynamic_sprite_attr_wr_en <= 1'b1;
                case (dynamic_attr_write_index)
                    3'd1: begin
                        dynamic_sprite_attr_wr_slot <= 4'd1;
                        dynamic_sprite_attr_wr_data <= {
                            1'b0,
                            render_control_frame[31],
                            render_control_frame[20:12], 1'b0,
                            render_control_frame[11:2], 1'b0,
                            render_control_frame[1] &&
                                render_control_frame[30]
                        };
                    end
                    3'd2: begin
                        dynamic_sprite_attr_wr_slot <= 4'd2;
                        dynamic_sprite_attr_wr_data <=
                            enemy_sprite_attr_frame[0];
                    end
                    3'd3: begin
                        dynamic_sprite_attr_wr_slot <= 4'd3;
                        dynamic_sprite_attr_wr_data <=
                            enemy_sprite_attr_frame[1];
                    end
                    3'd4: begin
                        dynamic_sprite_attr_wr_slot <= 4'd4;
                        dynamic_sprite_attr_wr_data <=
                            enemy_sprite_attr_frame[2];
                    end
                    default: begin
                        dynamic_sprite_attr_wr_slot <= 4'd5;
                        dynamic_sprite_attr_wr_data <=
                            enemy_sprite_attr_frame[3];
                    end
                endcase
                if (dynamic_attr_write_index == 3'd5)
                    dynamic_attr_write_index <= 3'd0;
                else
                    dynamic_attr_write_index <=
                        dynamic_attr_write_index + 1'b1;
            end else if (render_pattern_ready && render_frame_done) begin
                render_control_frame <= render_control_pixel;
                // Freeze all enemy attributes at this boundary.  The five
                // following BRAM writes then consume one coherent snapshot
                // even if software publishes the next update meanwhile.
                enemy_sprite_attr_frame[0] <= enemy_sprite_attr_aligned[0];
                enemy_sprite_attr_frame[1] <= enemy_sprite_attr_aligned[1];
                enemy_sprite_attr_frame[2] <= enemy_sprite_attr_aligned[2];
                enemy_sprite_attr_frame[3] <= enemy_sprite_attr_aligned[3];
                dynamic_sprite_attr_wr_en <= 1'b1;
                dynamic_sprite_attr_wr_slot <= 4'd0;
                dynamic_sprite_attr_wr_data <= {
                    1'b0,
                    render_control_pixel[31],
                    render_control_pixel[20:12], 1'b0,
                    render_control_pixel[11:2], 1'b0,
                    render_control_pixel[1] && !render_control_pixel[30]
                };
                dynamic_attr_write_index <= 3'd1;
                // Software encodes an even-pixel camera position as x/2 in
                // bits [29:21]. Latch it at the same frame boundary as the
                // sprite position so background and hero cannot tear apart.
                dynamic_scroll_x <= {
                    1'b0, render_control_pixel[29:21], 1'b0
                };
            end
        end
    end

    always_comb begin
        if (!render_pattern_ready) begin
            render_scroll_x = pattern_scroll_x;
            render_scroll_y = pattern_scroll_y;
        end else begin
            render_scroll_x = dynamic_scroll_x;
            render_scroll_y = 10'd0;
        end
    end

    always_comb begin
        if (!render_pattern_ready) begin
            render_sprite_attr_wr_en   = pattern_sprite_attr_wr_en;
            render_sprite_attr_wr_slot = pattern_sprite_attr_wr_slot;
            render_sprite_attr_wr_data = pattern_sprite_attr_wr_data;
        end else begin
            render_sprite_attr_wr_en   = dynamic_sprite_attr_wr_en;
            render_sprite_attr_wr_slot = dynamic_sprite_attr_wr_slot;
            render_sprite_attr_wr_data = dynamic_sprite_attr_wr_data;
        end
    end

    sprite_bringup_pattern render_test_pattern (
        .pixel_clk          (pixel_clk),
        .reset              (pixel_reset),
        .scroll_x           (pattern_scroll_x),
        .scroll_y           (pattern_scroll_y),
        .tilemap_wr_en      (pattern_tilemap_wr_en),
        .tilemap_wr_addr    (pattern_tilemap_wr_addr),
        .tilemap_wr_tile    (pattern_tilemap_wr_tile),
        .tile_gfx_wr_en     (pattern_tile_gfx_wr_en),
        .tile_gfx_wr_addr   (pattern_tile_gfx_wr_addr),
        .tile_gfx_wr_index  (pattern_tile_gfx_wr_index),
        .sprite_gfx_wr_en   (pattern_sprite_gfx_wr_en),
        .sprite_gfx_wr_addr (pattern_sprite_gfx_wr_addr),
        .sprite_gfx_wr_index(pattern_sprite_gfx_wr_index),
        .sprite_attr_wr_en  (pattern_sprite_attr_wr_en),
        .sprite_attr_wr_slot(pattern_sprite_attr_wr_slot),
        .sprite_attr_wr_data(pattern_sprite_attr_wr_data),
        .palette_wr_en      (pattern_palette_wr_en),
        .palette_wr_index   (pattern_palette_wr_index),
        .palette_wr_rgb565  (pattern_palette_wr_rgb565),
        .init_done          (render_init_done),
        .render_enable      (render_pattern_ready)
    );

    always_comb begin
        if (!render_pattern_ready) begin
            render_tilemap_wr_en       = pattern_tilemap_wr_en;
            render_tilemap_wr_addr     = pattern_tilemap_wr_addr;
            render_tilemap_wr_tile     = pattern_tilemap_wr_tile;
            render_tile_gfx_wr_en      = pattern_tile_gfx_wr_en;
            render_tile_gfx_wr_addr    = pattern_tile_gfx_wr_addr;
            render_tile_gfx_wr_index   = pattern_tile_gfx_wr_index;
            render_sprite_gfx_wr_en    = pattern_sprite_gfx_wr_en;
            render_sprite_gfx_wr_addr  = pattern_sprite_gfx_wr_addr;
            render_sprite_gfx_wr_index = pattern_sprite_gfx_wr_index;
            render_palette_wr_en       = pattern_palette_wr_en;
            render_palette_wr_index    = pattern_palette_wr_index;
            render_palette_wr_rgb565   = pattern_palette_wr_rgb565;
        end else begin
            render_tilemap_wr_en       = loader_tilemap_wr_en;
            render_tilemap_wr_addr     = loader_tilemap_wr_addr;
            render_tilemap_wr_tile     = loader_tilemap_wr_tile;
            render_tile_gfx_wr_en      = loader_tile_gfx_wr_en;
            render_tile_gfx_wr_addr    = loader_tile_gfx_wr_addr;
            render_tile_gfx_wr_index   = loader_tile_gfx_wr_index;
            render_sprite_gfx_wr_en    = loader_sprite_gfx_wr_en;
            render_sprite_gfx_wr_addr  = loader_sprite_gfx_wr_addr;
            render_sprite_gfx_wr_index = loader_sprite_gfx_wr_index;
            render_palette_wr_en       = loader_palette_wr_en;
            render_palette_wr_index    = loader_palette_wr_index;
            render_palette_wr_rgb565   = loader_palette_wr_rgb565;
        end
    end

    // Two hero banks provide tear-free animation; slots 2-5 are independently
    // moving enemies whose attributes are committed in the same frame-boundary
    // burst as the hero and camera.
    sprite_engine #(
        .SPRITE_COUNT (6)
    ) renderer (
        .pixel_clk          (pixel_clk),
        .reset              (pixel_reset),
        .pixel_req          (render_pixel_req),
        .pixel_req_x        (render_pixel_req_x),
        .pixel_req_y        (render_pixel_req_y),
        .pixel_req_ready    (render_pixel_req_ready),
        .rgb565             (renderer_rgb565),
        .rgb_valid          (rendered_rgb_valid),
        .rgb_ready          (rendered_rgb_ready),
        .rgb_x              (rendered_rgb_x),
        .rgb_y              (rendered_rgb_y),
        .rgb_frame_start    (),
        .rgb_frame_end      (),
        .scroll_x           (render_scroll_x),
        .scroll_y           (render_scroll_y),
        .tilemap_wr_en      (render_tilemap_wr_en),
        .tilemap_wr_addr    (render_tilemap_wr_addr),
        .tilemap_wr_tile    (render_tilemap_wr_tile),
        .tile_gfx_wr_en     (render_tile_gfx_wr_en),
        .tile_gfx_wr_addr   (render_tile_gfx_wr_addr),
        .tile_gfx_wr_index  (render_tile_gfx_wr_index),
        .sprite_gfx_wr_en   (render_sprite_gfx_wr_en),
        .sprite_gfx_wr_addr (render_sprite_gfx_wr_addr),
        .sprite_gfx_wr_index(render_sprite_gfx_wr_index),
        .sprite_attr_wr_en  (render_sprite_attr_wr_en),
        .sprite_attr_wr_slot(render_sprite_attr_wr_slot),
        .sprite_attr_wr_data(render_sprite_attr_wr_data),
        .palette_wr_en      (render_palette_wr_en),
        .palette_wr_index   (render_palette_wr_index),
        .palette_wr_rgb565  (render_palette_wr_rgb565)
    );

    // Opening-world scenery drawn after tile/sprite composition.  Keeping
    // the large title procedural avoids spending the scarce 64 tile IDs on
    // one-use lettering, while world_x makes it scroll away with the level.
    mario_title_overlay opening_title (
        .pixel_x    (rendered_rgb_x),
        .pixel_y    (rendered_rgb_y),
        .scroll_x   (render_scroll_x),
        .background (renderer_rgb565),
        .rgb565     (rendered_rgb565)
    );

    sprite_frame_stream render_stream (
        .pixel_clk       (pixel_clk),
        .reset           (pixel_reset),
        .enable          (render_enable && render_pattern_ready),
        .pixel_req       (render_pixel_req),
        .pixel_req_x     (render_pixel_req_x),
        .pixel_req_y     (render_pixel_req_y),
        .pixel_req_ready (render_pixel_req_ready),
        .rgb565          (rendered_rgb565),
        .rgb_valid       (rendered_rgb_valid),
        .rgb_ready       (rendered_rgb_ready),
        .rgb_x           (rendered_rgb_x),
        .rgb_y           (rendered_rgb_y),
        .m_axis_tdata    (s2mm_tdata),
        .m_axis_tkeep    (s2mm_tkeep),
        .m_axis_tvalid   (s2mm_tvalid),
        .m_axis_tready   (s2mm_tready),
        .m_axis_tuser    (s2mm_tuser),
        .m_axis_tlast    (s2mm_tlast),
        .frame_active    (render_frame_active),
        .frame_done      (render_frame_done)
    );

    hdmi_vdma_fifo_bridge #(
        .FIFO_DEPTH     (8192),
        .PREFILL_PIXELS (4096)
    ) video_fifo (
        .axis_reset          (axis_reset),
        .pixel_reset         (pixel_reset),
        .axis_clk            (ui_clk),
        .s_axis_tdata        (axis_tdata),
        .s_axis_tvalid       (axis_tvalid),
        .s_axis_tready       (axis_tready),
        .s_axis_tuser        (axis_tuser[0]),
        .s_axis_tlast        (axis_tlast),
        .flush_request       (hud_visible),
        .pixel_clk           (pixel_clk),
        .pixel_req           (pixel_req),
        .pixel_rgb565        (fifo_rgb565),
        .pixel_valid         (fifo_pixel_valid),
        .fifo_full           (fifo_full),
        .fifo_prog_full      (fifo_prog_full),
        .fifo_empty          (fifo_empty),
        .fifo_prog_empty     (fifo_prog_empty),
        .fifo_prefilled      (fifo_prefilled),
        .fifo_wr_data_count  (fifo_wr_data_count),
        .underflow           (fifo_underflow),
        .underflow_sticky    (underflow_sticky),
        .stream_error_sticky (stream_error_sticky)
    );

    assign video_reset = pixel_reset || !fifo_prefilled;

    game_hud_overlay game_hud (
        .pixel_x      (hdmi_pixel_x),
        .pixel_y      (hdmi_pixel_y),
        .background   (fifo_rgb565),
        .coin_count   (hud_coin_count),
        .health       (hud_health),
        .goal_reached (hud_goal_reached),
        .power_active (hud_power_active),
        .rgb565       (hud_rgb565)
    );

    hdmi_720p #(
        .PIXEL_READ_LATENCY (0)
    ) hdmi (
        .pixel_clk      (pixel_clk),
        .pixel_clk_5x   (pixel_clk_5x),
        .clocks_locked  (hdmi_locked),
        .reset          (video_reset),
        .pattern_sel    (2'd0),
        // The level-select screen comes directly from the CPU-drawn menu
        // framebuffer while render_enable is low.  HUD belongs only to the
        // active game and must not be composited over that menu.
        .rgb565         (hud_visible ? hud_rgb565 : fifo_rgb565),
        .solid_rgb565   (16'h0000),
        .pixel_x        (hdmi_pixel_x),
        .pixel_y        (hdmi_pixel_y),
        .pixel_de       (),
        .frame_start    (frame_start),
        .pixel_req      (pixel_req),
        .pixel_req_x    (),
        .pixel_req_y    (),
        .hdmi_clk_p     (tmds_clk_p),
        .hdmi_clk_n     (tmds_clk_n),
        .hdmi_data_p    (tmds_data_p),
        .hdmi_data_n    (tmds_data_n)
    );

    // LED0: MIG calibration; LED1: MIG UI heartbeat; LED2: FIFO has filled
    // and HDMI has been released; LED3: sticky FIFO underflow/stream error.
    assign led[0] = init_calib_complete;
    assign led[1] = ui_heartbeat[25];
    assign led[2] = fifo_prefilled;
    assign led[3] = underflow_sticky || stream_error_sticky;

    // JTAG ILA for the black-framebuffer bring-up. It distinguishes:
    // MicroBlaze DDR writes, VDMA DDR reads, AXI read errors, MM2S stream
    // activity, and FIFO fill level, all in the MIG ui_clk domain.
    ila_framebuffer_black framebuffer_debug (
        .clk     (ui_clk),
        .probe0  (init_calib_complete),
        .probe1  (axis_reset),
        .probe2  (axis_tvalid),
        .probe3  (axis_tready),
        .probe4  (axis_tdata),
        .probe5  (axis_tuser),
        .probe6  (axis_tlast),
        .probe7  (axi_arvalid),
        .probe8  (axi_arready),
        .probe9  (axi_araddr),
        .probe10 (axi_rvalid),
        .probe11 (axi_rready),
        .probe12 (axi_rresp),
        .probe13 (axi_rlast),
        .probe14 (axi_awvalid),
        .probe15 (axi_awready),
        .probe16 (axi_wvalid),
        .probe17 (axi_wready),
        .probe18 (axi_bvalid),
        .probe19 (axi_bready),
        .probe20 (axi_bresp),
        .probe21 (fifo_wr_data_count),
        .probe22 (fifo_prog_full),
        .probe23 (stream_error_sticky),
        .probe24 (sd_cs),
        .probe25 (sd_clk),
        .probe26 (sd_mosi),
        .probe27 (sd_miso)
    );
endmodule

// Large opening title embedded in world space.  It deliberately uses a small
// synthesizable bitmap font rather than a framebuffer asset, so the tile set
// remains available for terrain, pipes, pickups and larger connected clouds.
module mario_title_overlay (
    input  logic [10:0] pixel_x,
    input  logic [9:0]  pixel_y,
    input  logic [10:0] scroll_x,
    input  logic [15:0] background,
    output logic [15:0] rgb565
);
    integer world_x;
    integer character_index;
    integer glyph_x;
    integer glyph_y;
    integer local_x;
    integer local_y;
    integer cell_x;
    logic [7:0] character;
    logic [34:0] glyph;
    logic glyph_shadow;
    logic glyph_foreground;

    function automatic logic [34:0] title_font(input logic [7:0] code);
        begin
            case (code)
                8'h2E: title_font = {5'b00000,5'b00000,5'b00000,5'b00000,
                                      5'b00000,5'b01100,5'b01100};
                8'h41: title_font = {5'b01110,5'b10001,5'b10001,5'b11111,
                                      5'b10001,5'b10001,5'b10001};
                8'h42: title_font = {5'b11110,5'b10001,5'b10001,5'b11110,
                                      5'b10001,5'b10001,5'b11110};
                8'h45: title_font = {5'b11111,5'b10000,5'b10000,5'b11110,
                                      5'b10000,5'b10000,5'b11111};
                8'h49: title_font = {5'b11111,5'b00100,5'b00100,5'b00100,
                                      5'b00100,5'b00100,5'b11111};
                8'h4D: title_font = {5'b10001,5'b11011,5'b10101,5'b10101,
                                      5'b10001,5'b10001,5'b10001};
                8'h4F: title_font = {5'b01110,5'b10001,5'b10001,5'b10001,
                                      5'b10001,5'b10001,5'b01110};
                8'h50: title_font = {5'b11110,5'b10001,5'b10001,5'b11110,
                                      5'b10000,5'b10000,5'b10000};
                8'h52: title_font = {5'b11110,5'b10001,5'b10001,5'b11110,
                                      5'b10100,5'b10010,5'b10001};
                8'h53: title_font = {5'b01111,5'b10000,5'b10000,5'b01110,
                                      5'b00001,5'b00001,5'b11110};
                8'h55: title_font = {5'b10001,5'b10001,5'b10001,5'b10001,
                                      5'b10001,5'b10001,5'b01110};
                default: title_font = 35'b0;
            endcase
        end
    endfunction

    always_comb begin
        rgb565 = background;
        world_x = pixel_x + scroll_x;
        character = 8'h20;
        glyph = '0;
        character_index = 0;
        glyph_x = 0;
        glyph_y = 0;
        local_x = 0;
        local_y = 0;
        cell_x = 0;
        glyph_shadow = 1'b0;
        glyph_foreground = 1'b0;

        // Black drop shadow, cream trim and a warm orange center reproduce
        // the readable two-line title-card silhouette at 720p.
        if (world_x >= 352 && world_x < 928 &&
            pixel_y >= 88 && pixel_y < 304) begin
            if (world_x < 360 || world_x >= 920 ||
                pixel_y < 96 || pixel_y >= 296)
                rgb565 = 16'h0000;
            else if (world_x < 364 || world_x >= 916 ||
                     pixel_y < 100 || pixel_y >= 292)
                rgb565 = 16'hFF7B;
            else
                rgb565 = 16'hDAA2;

            // Small dark corner fasteners.
            if (((world_x >= 370 && world_x < 378) ||
                 (world_x >= 902 && world_x < 910)) &&
                ((pixel_y >= 106 && pixel_y < 114) ||
                 (pixel_y >= 278 && pixel_y < 286)))
                rgb565 = 16'h2104;
        end

        // SUPER: 5x7 glyphs at 8x scale, 48-pixel character pitch.
        if (world_x >= 520 && world_x < 760 &&
            pixel_y >= 116 && pixel_y < 176) begin
            local_y = pixel_y - 116;
            if (world_x < 568) begin character = 8'h53; cell_x = 520; end
            else if (world_x < 616) begin character = 8'h55; cell_x = 568; end
            else if (world_x < 664) begin character = 8'h50; cell_x = 616; end
            else if (world_x < 712) begin character = 8'h45; cell_x = 664; end
            else begin character = 8'h52; cell_x = 712; end
            glyph = title_font(character);
            local_x = world_x - cell_x;
            glyph_x = local_x >> 3;
            glyph_y = local_y >> 3;
            if (glyph_x < 5 && glyph_y < 7)
                glyph_foreground =
                    glyph[34 - (glyph_y * 5 + glyph_x)];
            glyph_x = (local_x - 4) >> 3;
            glyph_y = (local_y - 4) >> 3;
            if (local_x >= 4 && local_y >= 4 &&
                glyph_x < 5 && glyph_y < 7)
                glyph_shadow = glyph[34 - (glyph_y * 5 + glyph_x)];
            if (glyph_shadow)
                rgb565 = 16'h0000;
            if (glyph_foreground)
                rgb565 = 16'hFF7B;
        end

        // MARIO BROS.: 11 glyph cells at 8x scale, 48-pixel pitch.  Explicit
        // cell boundaries avoid divider/modulo logic on the live pixel path.
        if (world_x >= 376 && world_x < 904 &&
            pixel_y >= 194 && pixel_y < 254) begin
            local_y = pixel_y - 194;
            if (world_x < 424) begin character = 8'h4D; cell_x = 376; end
            else if (world_x < 472) begin character = 8'h41; cell_x = 424; end
            else if (world_x < 520) begin character = 8'h52; cell_x = 472; end
            else if (world_x < 568) begin character = 8'h49; cell_x = 520; end
            else if (world_x < 616) begin character = 8'h4F; cell_x = 568; end
            else if (world_x < 664) begin character = 8'h20; cell_x = 616; end
            else if (world_x < 712) begin character = 8'h42; cell_x = 664; end
            else if (world_x < 760) begin character = 8'h52; cell_x = 712; end
            else if (world_x < 808) begin character = 8'h4F; cell_x = 760; end
            else if (world_x < 856) begin character = 8'h53; cell_x = 808; end
            else begin character = 8'h2E; cell_x = 856; end
            glyph = title_font(character);
            local_x = world_x - cell_x;
            glyph_x = local_x >> 3;
            glyph_y = local_y >> 3;
            if (glyph_x < 5 && glyph_y < 7)
                glyph_foreground =
                    glyph[34 - (glyph_y * 5 + glyph_x)];
            glyph_x = (local_x - 4) >> 3;
            glyph_y = (local_y - 4) >> 3;
            if (local_x >= 4 && local_y >= 4 &&
                glyph_x < 5 && glyph_y < 7)
                glyph_shadow = glyph[34 - (glyph_y * 5 + glyph_x)];
            if (glyph_shadow)
                rgb565 = 16'h0000;
            if (glyph_foreground)
                rgb565 = 16'hFF7B;
        end
    end
endmodule

// Fixed-screen status layer drawn after the DDR framebuffer.  It therefore
// stays anchored while the world scrolls and does not consume Sprite slots.
module game_hud_overlay (
    input  logic [10:0] pixel_x,
    input  logic [9:0]  pixel_y,
    input  logic [15:0] background,
    input  logic [5:0]  coin_count,
    input  logic [1:0]  health,
    input  logic        goal_reached,
    input  logic        power_active,
    output logic [15:0] rgb565
);
    logic [7:0] character;
    logic [34:0] glyph;
    integer local_x;
    integer local_y;
    integer character_index;
    integer glyph_x;
    integer glyph_y;

    function automatic logic [34:0] font5x7(input logic [7:0] code);
        begin
            case (code)
                8'h30: font5x7 = {5'b01110,5'b10001,5'b10011,5'b10101,
                                   5'b11001,5'b10001,5'b01110};
                8'h31: font5x7 = {5'b00100,5'b01100,5'b00100,5'b00100,
                                   5'b00100,5'b00100,5'b01110};
                8'h32: font5x7 = {5'b01110,5'b10001,5'b00001,5'b00010,
                                   5'b00100,5'b01000,5'b11111};
                8'h33: font5x7 = {5'b11110,5'b00001,5'b00001,5'b01110,
                                   5'b00001,5'b00001,5'b11110};
                8'h34: font5x7 = {5'b00010,5'b00110,5'b01010,5'b10010,
                                   5'b11111,5'b00010,5'b00010};
                8'h35: font5x7 = {5'b11111,5'b10000,5'b11110,5'b00001,
                                   5'b00001,5'b10001,5'b01110};
                8'h36: font5x7 = {5'b00110,5'b01000,5'b10000,5'b11110,
                                   5'b10001,5'b10001,5'b01110};
                8'h37: font5x7 = {5'b11111,5'b00001,5'b00010,5'b00100,
                                   5'b01000,5'b01000,5'b01000};
                8'h38: font5x7 = {5'b01110,5'b10001,5'b10001,5'b01110,
                                   5'b10001,5'b10001,5'b01110};
                8'h39: font5x7 = {5'b01110,5'b10001,5'b10001,5'b01111,
                                   5'b00001,5'b00010,5'b11100};
                8'h2F: font5x7 = {5'b00001,5'b00010,5'b00100,5'b01000,
                                   5'b10000,5'b00000,5'b00000};
                8'h41: font5x7 = {5'b01110,5'b10001,5'b10001,5'b11111,
                                   5'b10001,5'b10001,5'b10001};
                8'h43: font5x7 = {5'b01111,5'b10000,5'b10000,5'b10000,
                                   5'b10000,5'b10000,5'b01111};
                8'h45: font5x7 = {5'b11111,5'b10000,5'b10000,5'b11110,
                                   5'b10000,5'b10000,5'b11111};
                8'h47: font5x7 = {5'b01111,5'b10000,5'b10000,5'b10111,
                                   5'b10001,5'b10001,5'b01111};
                8'h49: font5x7 = {5'b01110,5'b00100,5'b00100,5'b00100,
                                   5'b00100,5'b00100,5'b01110};
                8'h4C: font5x7 = {5'b10000,5'b10000,5'b10000,5'b10000,
                                   5'b10000,5'b10000,5'b11111};
                8'h4D: font5x7 = {5'b10001,5'b11011,5'b10101,5'b10101,
                                   5'b10001,5'b10001,5'b10001};
                8'h4E: font5x7 = {5'b10001,5'b11001,5'b10101,5'b10011,
                                   5'b10001,5'b10001,5'b10001};
                8'h4F: font5x7 = {5'b01110,5'b10001,5'b10001,5'b10001,
                                   5'b10001,5'b10001,5'b01110};
                8'h52: font5x7 = {5'b11110,5'b10001,5'b10001,5'b11110,
                                   5'b10100,5'b10010,5'b10001};
                8'h53: font5x7 = {5'b01111,5'b10000,5'b10000,5'b01110,
                                   5'b00001,5'b00001,5'b11110};
                8'h54: font5x7 = {5'b11111,5'b00100,5'b00100,5'b00100,
                                   5'b00100,5'b00100,5'b00100};
                8'h56: font5x7 = {5'b10001,5'b10001,5'b10001,5'b10001,
                                   5'b10001,5'b01010,5'b00100};
                default: font5x7 = 35'b0;
            endcase
        end
    endfunction

    always_comb begin
        rgb565 = background;
        character = 8'h20;
        glyph = 35'b0;
        local_x = 0;
        local_y = 0;
        character_index = 0;
        glyph_x = 0;
        glyph_y = 0;

        // Persistent top-left "COINS 00/34" panel.
        if (pixel_x >= 16 && pixel_x < 396 &&
            pixel_y >= 16 && pixel_y < 64) begin
            rgb565 = (pixel_x < 20 || pixel_x >= 392 ||
                      pixel_y < 20 || pixel_y >= 60)
                     ? 16'hFFE0 : 16'h18C3;
            if (pixel_x >= 28 && pixel_x < 380 &&
                pixel_y >= 26 && pixel_y < 54) begin
                local_x = pixel_x - 28;
                local_y = pixel_y - 26;
                character_index = local_x >> 5;
                glyph_x = (local_x & 31) >> 2;
                glyph_y = local_y >> 2;
                case (character_index)
                    0: character = 8'h43; // C
                    1: character = 8'h4F; // O
                    2: character = 8'h49; // I
                    3: character = 8'h4E; // N
                    4: character = 8'h53; // S
                    6: character = 8'h30 + coin_count / 10;
                    7: character = 8'h30 + coin_count % 10;
                    8: character = 8'h2F; // /
                    9: character = 8'h33;
                    10: character = 8'h34;
                    default: character = 8'h20;
                endcase
                glyph = font5x7(character);
                if (glyph_x < 5 && glyph_y < 7 &&
                    glyph[34 - (glyph_y * 5 + glyph_x)])
                    rgb565 = 16'hFFFF;
            end
        end

        // Fixed top-right three-segment health bar. Empty segments remain
        // visible in dark gray, while current health is bright red.
        if (pixel_x >= 1000 && pixel_x < 1264 &&
            pixel_y >= 16 && pixel_y < 64) begin
            rgb565 = (pixel_x < 1004 || pixel_x >= 1260 ||
                      pixel_y < 20 || pixel_y >= 60)
                     ? 16'hFFFF : 16'h18C3;
            if (pixel_x >= 1020 && pixel_x < 1244 &&
                pixel_y >= 28 && pixel_y < 52) begin
                if (pixel_x < 1076)
                    rgb565 = health >= 1 ? 16'hF800 : 16'h4208;
                else if (pixel_x >= 1092 && pixel_x < 1148)
                    rgb565 = health >= 2 ? 16'hF800 : 16'h4208;
                else if (pixel_x >= 1164 && pixel_x < 1220)
                    rgb565 = health >= 3 ? 16'hF800 : 16'h4208;
            end
        end

        // The star pickup grants five seconds of invincibility.  Keep a
        // bright fixed-screen indicator visible while software's timer runs.
        if (power_active && pixel_x >= 488 && pixel_x < 792 &&
            pixel_y >= 16 && pixel_y < 64) begin
            rgb565 = (pixel_x < 492 || pixel_x >= 788 ||
                      pixel_y < 20 || pixel_y >= 60)
                     ? 16'hFFE0 : 16'h0320;
            if (pixel_x >= 568 && pixel_x < 696 &&
                pixel_y >= 26 && pixel_y < 54) begin
                local_x = pixel_x - 568;
                local_y = pixel_y - 26;
                character_index = local_x >> 5;
                glyph_x = (local_x & 31) >> 2;
                glyph_y = local_y >> 2;
                case (character_index)
                    0: character = 8'h53; // S
                    1: character = 8'h54; // T
                    2: character = 8'h41; // A
                    3: character = 8'h52; // R
                    default: character = 8'h20;
                endcase
                glyph = font5x7(character);
                if (glyph_x < 5 && glyph_y < 7 &&
                    glyph[34 - (glyph_y * 5 + glyph_x)])
                    rgb565 = 16'hFFFF;
            end
        end

        // Latched completion banner.  The message remains visible even if
        // the hero subsequently walks away from the goal tile.
        if (goal_reached && pixel_x >= 424 && pixel_x < 856 &&
            pixel_y >= 292 && pixel_y < 348) begin
            rgb565 = (pixel_x < 432 || pixel_x >= 848 ||
                      pixel_y < 300 || pixel_y >= 340)
                     ? 16'hFFE0 : 16'h2104;
            if (pixel_x >= 464 && pixel_x < 816 &&
                pixel_y >= 306 && pixel_y < 334) begin
                local_x = pixel_x - 464;
                local_y = pixel_y - 306;
                character_index = local_x >> 5;
                glyph_x = (local_x & 31) >> 2;
                glyph_y = local_y >> 2;
                case (character_index)
                    0: character = 8'h4C; // L
                    1: character = 8'h45; // E
                    2: character = 8'h56; // V
                    3: character = 8'h45; // E
                    4: character = 8'h4C; // L
                    6: character = 8'h43; // C
                    7: character = 8'h4C; // L
                    8: character = 8'h45; // E
                    9: character = 8'h41; // A
                    10: character = 8'h52; // R
                    default: character = 8'h20;
                endcase
                glyph = font5x7(character);
                if (glyph_x < 5 && glyph_y < 7 &&
                    glyph[34 - (glyph_y * 5 + glyph_x)])
                    rgb565 = 16'hFFFF;
            end
        end

        // Health zero is held for two seconds by software.  Show a clear
        // failure panel for that entire interval instead of immediately
        // refilling the bar and making the loss invisible to the player.
        if (health == 0 && pixel_x >= 456 && pixel_x < 824 &&
            pixel_y >= 292 && pixel_y < 348) begin
            rgb565 = (pixel_x < 464 || pixel_x >= 816 ||
                      pixel_y < 300 || pixel_y >= 340)
                     ? 16'hF800 : 16'h2104;
            if (pixel_x >= 504 && pixel_x < 792 &&
                pixel_y >= 306 && pixel_y < 334) begin
                local_x = pixel_x - 504;
                local_y = pixel_y - 306;
                character_index = local_x >> 5;
                glyph_x = (local_x & 31) >> 2;
                glyph_y = local_y >> 2;
                case (character_index)
                    0: character = 8'h47; // G
                    1: character = 8'h41; // A
                    2: character = 8'h4D; // M
                    3: character = 8'h45; // E
                    5: character = 8'h4F; // O
                    6: character = 8'h56; // V
                    7: character = 8'h45; // E
                    8: character = 8'h52; // R
                    default: character = 8'h20;
                endcase
                glyph = font5x7(character);
                if (glyph_x < 5 && glyph_y < 7 &&
                    glyph[34 - (glyph_y * 5 + glyph_x)])
                    rgb565 = 16'hFFFF;
            end
        end
    end
endmodule
