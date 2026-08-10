// Standalone CF7A100B DDR3 test.
//
// After MIG calibration this module writes 32 KiB through the 256-bit AXI
// interface, reads every beat back, compares it, and repeats with a new data
// pattern. No MicroBlaze, VDMA or HDMI logic is involved.
module ddr3_axi_selftest_top (
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

    output logic [3:0]  led
);
    localparam int AXI_ADDR_WIDTH = 29;
    localparam int AXI_DATA_WIDTH = 256;
    localparam int TEST_BEATS     = 1024; // 1024 * 32 bytes = 32 KiB

    logic ui_clk;
    logic ui_clk_sync_rst;
    logic init_calib_complete;
    logic mig_mmcm_locked;
    logic axi_aresetn;
    logic sys_clk_ibuf;
    logic sys_clk_buf;
    logic clk_ref_fb;
    logic clk_ref_fb_buf;
    logic clk_ref_200_unbuf;
    logic clk_ref_200;
    logic clk_ref_locked;
    logic [11:0] device_temp;

    logic [3:0]                 axi_awid;
    logic [AXI_ADDR_WIDTH-1:0]  axi_awaddr;
    logic [7:0]                 axi_awlen;
    logic [2:0]                 axi_awsize;
    logic [1:0]                 axi_awburst;
    logic [0:0]                 axi_awlock;
    logic [3:0]                 axi_awcache;
    logic [2:0]                 axi_awprot;
    logic [3:0]                 axi_awqos;
    logic                       axi_awvalid;
    logic                       axi_awready;

    logic [AXI_DATA_WIDTH-1:0]  axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0] axi_wstrb;
    logic                       axi_wlast;
    logic                       axi_wvalid;
    logic                       axi_wready;

    logic [3:0]                 axi_bid;
    logic [1:0]                 axi_bresp;
    logic                       axi_bvalid;
    logic                       axi_bready;

    logic [3:0]                 axi_arid;
    logic [AXI_ADDR_WIDTH-1:0]  axi_araddr;
    logic [7:0]                 axi_arlen;
    logic [2:0]                 axi_arsize;
    logic [1:0]                 axi_arburst;
    logic [0:0]                 axi_arlock;
    logic [3:0]                 axi_arcache;
    logic [2:0]                 axi_arprot;
    logic [3:0]                 axi_arqos;
    logic                       axi_arvalid;
    logic                       axi_arready;

    logic [3:0]                 axi_rid;
    logic [AXI_DATA_WIDTH-1:0]  axi_rdata;
    logic [1:0]                 axi_rresp;
    logic                       axi_rlast;
    logic                       axi_rvalid;
    logic                       axi_rready;

    logic [15:0] beat_index;
    logic [15:0] pass_index;
    logic [26:0] heartbeat_count;
    logic        pass_seen;
    logic        error_sticky;
    logic        aw_accepted;
    logic        w_accepted;

    typedef enum logic [2:0] {
        WAIT_CALIB,
        WRITE_SEND,
        WRITE_RESPONSE,
        READ_SEND,
        READ_DATA
    } test_state_t;
    test_state_t state;

    function automatic logic [255:0] make_pattern (
        input logic [15:0] pass_number,
        input logic [15:0] beat_number
    );
        integer lane;
        begin
            for (lane = 0; lane < 8; lane = lane + 1)
                make_pattern[lane*32 +: 32] =
                    32'hA5A5_5A5A ^ {pass_number, beat_number} ^
                    (32'h9E37_79B9 * lane);
        end
    endfunction

    wire [AXI_ADDR_WIDTH-1:0] test_address =
        {{(AXI_ADDR_WIDTH-16){1'b0}}, beat_index} << 5;
    wire [AXI_DATA_WIDTH-1:0] expected_data =
        make_pattern(pass_index, beat_index);

    assign axi_awid    = 4'd0;
    assign axi_awaddr  = test_address;
    assign axi_awlen   = 8'd0;
    assign axi_awsize  = 3'd5; // 32 bytes per 256-bit transfer
    assign axi_awburst = 2'b01;
    assign axi_awlock  = 1'b0;
    assign axi_awcache = 4'b0011;
    assign axi_awprot  = 3'b000;
    assign axi_awqos   = 4'd0;
    assign axi_awvalid = (state == WRITE_SEND) && !aw_accepted;

    assign axi_wdata   = expected_data;
    assign axi_wstrb   = {AXI_DATA_WIDTH/8{1'b1}};
    assign axi_wlast   = 1'b1;
    assign axi_wvalid  = (state == WRITE_SEND) && !w_accepted;
    assign axi_bready  = (state == WRITE_RESPONSE);

    assign axi_arid    = 4'd0;
    assign axi_araddr  = test_address;
    assign axi_arlen   = 8'd0;
    assign axi_arsize  = 3'd5;
    assign axi_arburst = 2'b01;
    assign axi_arlock  = 1'b0;
    assign axi_arcache = 4'b0011;
    assign axi_arprot  = 3'b000;
    assign axi_arqos   = 4'd0;
    assign axi_arvalid = (state == READ_SEND);
    assign axi_rready  = (state == READ_DATA);

    // MIG's AXI reset is synchronous to ui_clk, matching its example design.
    always_ff @(posedge ui_clk)
        axi_aresetn <= ~ui_clk_sync_rst;

    always_ff @(posedge ui_clk) begin
        if (ui_clk_sync_rst) begin
            state           <= WAIT_CALIB;
            beat_index      <= 16'd0;
            pass_index      <= 16'd0;
            heartbeat_count <= 27'd0;
            pass_seen       <= 1'b0;
            error_sticky    <= 1'b0;
            aw_accepted     <= 1'b0;
            w_accepted      <= 1'b0;
        end else begin
            heartbeat_count <= heartbeat_count + 1'b1;

            case (state)
                WAIT_CALIB: begin
                    beat_index  <= 16'd0;
                    aw_accepted <= 1'b0;
                    w_accepted  <= 1'b0;
                    if (init_calib_complete)
                        state <= WRITE_SEND;
                end

                WRITE_SEND: begin
                    if (axi_awready)
                        aw_accepted <= 1'b1;
                    if (axi_wready)
                        w_accepted <= 1'b1;

                    if ((aw_accepted || axi_awready) &&
                        (w_accepted || axi_wready)) begin
                        aw_accepted <= 1'b0;
                        w_accepted  <= 1'b0;
                        state       <= WRITE_RESPONSE;
                    end
                end

                WRITE_RESPONSE: begin
                    if (axi_bvalid) begin
                        if (axi_bresp != 2'b00)
                            error_sticky <= 1'b1;

                        if (beat_index == TEST_BEATS-1) begin
                            beat_index <= 16'd0;
                            state      <= READ_SEND;
                        end else begin
                            beat_index <= beat_index + 1'b1;
                            state      <= WRITE_SEND;
                        end
                    end
                end

                READ_SEND: begin
                    if (axi_arready)
                        state <= READ_DATA;
                end

                READ_DATA: begin
                    if (axi_rvalid) begin
                        if ((axi_rresp != 2'b00) || !axi_rlast ||
                            (axi_rdata != expected_data))
                            error_sticky <= 1'b1;

                        if (beat_index == TEST_BEATS-1) begin
                            if (!error_sticky &&
                                (axi_rresp == 2'b00) && axi_rlast &&
                                (axi_rdata == expected_data))
                                pass_seen <= 1'b1;
                            pass_index <= pass_index + 1'b1;
                            beat_index <= 16'd0;
                            state      <= WRITE_SEND;
                        end else begin
                            beat_index <= beat_index + 1'b1;
                            state      <= READ_SEND;
                        end
                    end
                end

                default: state <= WAIT_CALIB;
            endcase
        end
    end

    // LED0: MIG calibration complete.
    // LED1: ui_clk/test heartbeat.
    // LED2: at least one complete write/read/compare pass.
    // LED3: sticky AXI response or data comparison error.
    assign led[0] = init_calib_complete;
    assign led[1] = heartbeat_count[25];
    assign led[2] = pass_seen;
    assign led[3] = error_sticky;

    // R4 is buffered once here. MIG is configured for "No Buffer" on both
    // clock inputs so the shared 50 MHz clock and internally generated
    // 200 MHz IODELAY reference do not create duplicate input buffers.
    IBUF sys_clk_input_buffer (
        .I (sys_clk_i),
        .O (sys_clk_ibuf)
    );

    BUFG sys_clk_global_buffer (
        .I (sys_clk_ibuf),
        .O (sys_clk_buf)
    );

    // 50 MHz -> 800 MHz VCO -> 200 MHz reference clock.
    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKIN1_PERIOD      (20.000),
        .DIVCLK_DIVIDE      (1),
        .CLKFBOUT_MULT_F    (16.000),
        .CLKOUT0_DIVIDE_F   (4.000),
        .STARTUP_WAIT       ("FALSE")
    ) ref_clock_mmcm (
        .CLKIN1   (sys_clk_buf),
        .CLKFBIN  (clk_ref_fb_buf),
        .RST      (~sys_rst_n),
        .PWRDWN   (1'b0),
        .CLKFBOUT (clk_ref_fb),
        .CLKOUT0  (clk_ref_200_unbuf),
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
        .aresetn             (axi_aresetn),
        .app_sr_req          (1'b0),
        .app_ref_req         (1'b0),
        .app_zq_req          (1'b0),
        .app_sr_active       (),
        .app_ref_ack         (),
        .app_zq_ack          (),
        .device_temp         (device_temp),

        .s_axi_awid          (axi_awid),
        .s_axi_awaddr        (axi_awaddr),
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
        .s_axi_bid           (axi_bid),
        .s_axi_bresp         (axi_bresp),
        .s_axi_bvalid        (axi_bvalid),
        .s_axi_bready        (axi_bready),
        .s_axi_arid          (axi_arid),
        .s_axi_araddr        (axi_araddr),
        .s_axi_arlen         (axi_arlen),
        .s_axi_arsize        (axi_arsize),
        .s_axi_arburst       (axi_arburst),
        .s_axi_arlock        (axi_arlock),
        .s_axi_arcache       (axi_arcache),
        .s_axi_arprot        (axi_arprot),
        .s_axi_arqos         (axi_arqos),
        .s_axi_arvalid       (axi_arvalid),
        .s_axi_arready       (axi_arready),
        .s_axi_rid           (axi_rid),
        .s_axi_rdata         (axi_rdata),
        .s_axi_rresp         (axi_rresp),
        .s_axi_rlast         (axi_rlast),
        .s_axi_rvalid        (axi_rvalid),
        .s_axi_rready        (axi_rready),

        .sys_clk_i           (sys_clk_buf),
        .clk_ref_i           (clk_ref_200),
        .sys_rst             (sys_rst_n & clk_ref_locked)
    );
endmodule
