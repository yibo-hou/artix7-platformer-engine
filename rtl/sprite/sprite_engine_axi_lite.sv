// AXI4-Lite control plane for sprite_engine and sprite_asset_unpacker.
//
// AXI clock domain: register access and DMA launch/status.
// Pixel clock domain: camera, sprite attributes and palette write pulses.
module sprite_engine_axi_lite #(
    parameter integer AXI_ADDR_WIDTH = 12
) (
    input  logic                      s_axi_aclk,
    input  logic                      s_axi_aresetn,
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,
    input  logic [31:0]               s_axi_wdata,
    input  logic [3:0]                s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,
    output logic [1:0]                s_axi_bresp,
    output logic                      s_axi_bvalid,
    input  logic                      s_axi_bready,
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,
    output logic [31:0]               s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output logic                      s_axi_rvalid,
    input  logic                      s_axi_rready,

    // Sprite-engine configuration in pixel_clk domain.
    input  logic        pixel_clk,
    input  logic        pixel_reset,
    output logic [10:0] scroll_x,
    output logic [9:0]  scroll_y,
    output logic        render_enable,
    output logic        sprite_attr_wr_en,
    output logic [3:0]  sprite_attr_wr_slot,
    output logic [23:0] sprite_attr_wr_data,
    output logic        palette_wr_en,
    output logic [3:0]  palette_wr_index,
    output logic [15:0] palette_wr_rgb565,
    output logic [1:0]  asset_dest_kind,
    output logic [15:0] asset_dest_addr,
    output logic        asset_status_clear,
    input  logic        asset_busy,
    input  logic        asset_done,
    input  logic        asset_error
);
    localparam logic [3:0] CMD_SCROLL  = 4'd0;
    localparam logic [3:0] CMD_SPRITE  = 4'd1;
    localparam logic [3:0] CMD_PALETTE = 4'd2;
    localparam logic [3:0] CMD_ASSET_TARGET = 4'd3;
    localparam logic [3:0] CMD_STATUS_CLEAR = 4'd4;
    localparam logic [3:0] CMD_RENDER_ENABLE = 4'd5;

    logic [AXI_ADDR_WIDTH-1:0] awaddr_hold;
    logic [31:0] wdata_hold;
    logic [3:0]  wstrb_hold;
    logic aw_hold_valid;
    logic w_hold_valid;
    logic write_needs_fifo;
    logic [47:0] write_command;
    logic write_conflicts_dma;
    logic command_fifo_wr_en;
    logic command_fifo_full;
    logic command_fifo_wr_busy;
    logic [47:0] command_fifo_dout;
    logic command_fifo_empty;
    logic command_fifo_rd_en;
    logic command_fifo_rd_busy;
    logic write_commit;
    logic asset_busy_sync1;
    logic asset_busy_sync2;
    logic asset_done_sync1;
    logic asset_done_sync2;
    logic asset_error_sync1;
    logic asset_error_sync2;
    logic [1:0] asset_dest_kind_axi;
    logic [15:0] asset_dest_addr_axi;

    function automatic logic [31:0] apply_strobes(
        input logic [31:0] old_value,
        input logic [31:0] new_value,
        input logic [3:0] strobes
    );
        integer i;
        begin
            apply_strobes = old_value;
            for (i = 0; i < 4; i = i + 1)
                if (strobes[i])
                    apply_strobes[i*8 +: 8] = new_value[i*8 +: 8];
        end
    endfunction

    always_comb begin
        write_needs_fifo = 1'b0;
        write_command = 48'h0;

        if (awaddr_hold[AXI_ADDR_WIDTH-1:0] == 12'h008) begin
            write_needs_fifo = 1'b1;
            write_command[47:44] = CMD_RENDER_ENABLE;
            write_command[0] = wdata_hold[0];
        end else if (awaddr_hold[AXI_ADDR_WIDTH-1:0] == 12'h014) begin
            write_needs_fifo = 1'b1;
            write_command[47:44] = CMD_SCROLL;
            write_command[23:0] = wdata_hold[23:0];
        end else if ((awaddr_hold >= 12'h040) &&
                     (awaddr_hold < 12'h080)) begin
            write_needs_fifo = 1'b1;
            write_command[47:44] = CMD_SPRITE;
            write_command[43:28] = (awaddr_hold - 12'h040) >> 2;
            write_command[23:0] = wdata_hold[23:0];
        end else if ((awaddr_hold >= 12'h080) &&
                     (awaddr_hold < 12'h0C0)) begin
            write_needs_fifo = 1'b1;
            write_command[47:44] = CMD_PALETTE;
            write_command[43:28] = (awaddr_hold - 12'h080) >> 2;
            write_command[15:0] = wdata_hold[15:0];
        end else if (awaddr_hold[AXI_ADDR_WIDTH-1:0] == 12'h00C) begin
            write_needs_fifo = 1'b1;
            write_command[47:44] = CMD_ASSET_TARGET;
            write_command[43:42] = wdata_hold[31:30];
            write_command[15:0] = wdata_hold[15:0];
        end else if ((awaddr_hold[AXI_ADDR_WIDTH-1:0] == 12'h000) &&
                     wdata_hold[0]) begin
            write_needs_fifo = 1'b1;
            write_command[47:44] = CMD_STATUS_CLEAR;
        end
    end

    assign write_conflicts_dma =
        write_needs_fifo && (write_command[47:44] == CMD_PALETTE) &&
        asset_busy_sync2;

    assign s_axi_awready = !aw_hold_valid && !s_axi_bvalid;
    assign s_axi_wready  = !w_hold_valid && !s_axi_bvalid;
    assign write_commit = aw_hold_valid && w_hold_valid &&
                          (!write_needs_fifo ||
                           (!write_conflicts_dma &&
                            !command_fifo_full && !command_fifo_wr_busy));
    assign command_fifo_wr_en = write_commit && write_needs_fifo;
    assign s_axi_bresp = 2'b00;

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            awaddr_hold     <= '0;
            wdata_hold      <= '0;
            wstrb_hold      <= '0;
            aw_hold_valid   <= 1'b0;
            w_hold_valid    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            asset_dest_kind_axi <= '0;
            asset_dest_addr_axi <= '0;
        end else begin
            if (s_axi_awready && s_axi_awvalid) begin
                awaddr_hold   <= s_axi_awaddr;
                aw_hold_valid <= 1'b1;
            end
            if (s_axi_wready && s_axi_wvalid) begin
                wdata_hold   <= s_axi_wdata;
                wstrb_hold   <= s_axi_wstrb;
                w_hold_valid <= 1'b1;
            end

            if (write_commit) begin
                if (awaddr_hold == 12'h00C) begin
                    asset_dest_kind_axi <= wdata_hold[31:30];
                    asset_dest_addr_axi <= wdata_hold[15:0];
                end
                case (awaddr_hold)
                    default: begin
                    end
                endcase

                aw_hold_valid <= 1'b0;
                w_hold_valid  <= 1'b0;
                s_axi_bvalid  <= 1'b1;
            end

            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    assign s_axi_arready = !s_axi_rvalid;
    assign s_axi_rresp = 2'b00;

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= '0;
        end else begin
            if (s_axi_arready && s_axi_arvalid) begin
                case (s_axi_araddr)
                    12'h004: s_axi_rdata <= {
                        27'h0, command_fifo_full, asset_error_sync2,
                        asset_done_sync2, asset_busy_sync2, 1'b0
                    };
                    12'h00C: s_axi_rdata <= {
                        asset_dest_kind_axi, 14'h0, asset_dest_addr_axi
                    };
                    default: s_axi_rdata <= 32'h0;
                endcase
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    xpm_fifo_async #(
        .CDC_SYNC_STAGES(2),
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("distributed"),
        .FIFO_READ_LATENCY(0),
        .FIFO_WRITE_DEPTH(32),
        .FULL_RESET_VALUE(0),
        .PROG_EMPTY_THRESH(5),
        .PROG_FULL_THRESH(27),
        .RD_DATA_COUNT_WIDTH(6),
        .READ_DATA_WIDTH(48),
        .READ_MODE("fwft"),
        .RELATED_CLOCKS(0),
        .SIM_ASSERT_CHK(1),
        .USE_ADV_FEATURES("0000"),
        .WAKEUP_TIME(0),
        .WRITE_DATA_WIDTH(48),
        .WR_DATA_COUNT_WIDTH(6)
    ) command_fifo (
        .rst           (!s_axi_aresetn),
        .wr_clk        (s_axi_aclk),
        .wr_en         (command_fifo_wr_en),
        .din           (write_command),
        .full          (command_fifo_full),
        .wr_rst_busy   (command_fifo_wr_busy),
        .rd_clk        (pixel_clk),
        .rd_en         (command_fifo_rd_en),
        .dout          (command_fifo_dout),
        .empty         (command_fifo_empty),
        .rd_rst_busy   (command_fifo_rd_busy),
        .almost_empty  (),
        .almost_full   (),
        .data_valid    (),
        .dbiterr       (),
        .injectdbiterr (1'b0),
        .injectsbiterr (1'b0),
        .overflow      (),
        .prog_empty    (),
        .prog_full     (),
        .rd_data_count (),
        .sbiterr       (),
        .sleep         (1'b0),
        .underflow     (),
        .wr_ack        (),
        .wr_data_count ()
    );

    assign command_fifo_rd_en =
        !command_fifo_empty && !command_fifo_rd_busy;

    always_ff @(posedge pixel_clk) begin
        if (pixel_reset) begin
            scroll_x             <= '0;
            scroll_y             <= '0;
            render_enable        <= 1'b0;
            sprite_attr_wr_en    <= 1'b0;
            sprite_attr_wr_slot  <= '0;
            sprite_attr_wr_data  <= '0;
            palette_wr_en        <= 1'b0;
            palette_wr_index     <= '0;
            palette_wr_rgb565    <= '0;
            asset_dest_kind      <= '0;
            asset_dest_addr      <= '0;
            asset_status_clear   <= 1'b0;
        end else begin
            sprite_attr_wr_en <= 1'b0;
            palette_wr_en     <= 1'b0;
            asset_status_clear <= 1'b0;

            if (command_fifo_rd_en) begin
                case (command_fifo_dout[47:44])
                    CMD_SCROLL: begin
                        scroll_x <= command_fifo_dout[10:0];
                        scroll_y <= command_fifo_dout[20:11];
                    end
                    CMD_RENDER_ENABLE: begin
                        render_enable <= command_fifo_dout[0];
                    end
                    CMD_SPRITE: begin
                        sprite_attr_wr_en   <= 1'b1;
                        sprite_attr_wr_slot <= command_fifo_dout[31:28];
                        sprite_attr_wr_data <= command_fifo_dout[23:0];
                    end
                    CMD_PALETTE: begin
                        palette_wr_en     <= 1'b1;
                        palette_wr_index  <= command_fifo_dout[31:28];
                        palette_wr_rgb565 <= command_fifo_dout[15:0];
                    end
                    CMD_ASSET_TARGET: begin
                        asset_dest_kind <= command_fifo_dout[43:42];
                        asset_dest_addr <= command_fifo_dout[15:0];
                    end
                    CMD_STATUS_CLEAR:
                        asset_status_clear <= 1'b1;
                    default: begin
                    end
                endcase
            end
        end
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            asset_busy_sync1  <= 1'b0;
            asset_busy_sync2  <= 1'b0;
            asset_done_sync1  <= 1'b0;
            asset_done_sync2  <= 1'b0;
            asset_error_sync1 <= 1'b0;
            asset_error_sync2 <= 1'b0;
        end else begin
            asset_busy_sync1  <= asset_busy;
            asset_busy_sync2  <= asset_busy_sync1;
            asset_done_sync1  <= asset_done;
            asset_done_sync2  <= asset_done_sync1;
            asset_error_sync1 <= asset_error;
            asset_error_sync2 <= asset_error_sync1;
        end
    end
endmodule
