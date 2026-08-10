# Artix-7 720p HDMI output

This folder is a reusable, video-only HDMI/DVI transmitter:

```text
50 MHz board clock --> Vivado Clocking Wizard
                         |--> 74.25 MHz pixel_clk
                         \--> 371.25 MHz pixel_clk_5x

pixel_clk --> 720p timing --> RGB565 source --> TMDS encoders
                                                   |
pixel_clk_5x --------------------------------> OSERDESE2 --> OBUFDS
```

It generates standard 1280x720 progressive timing at 60 Hz:

| Item | Active | Front porch | Sync | Back porch | Total |
|---|---:|---:|---:|---:|---:|
| Horizontal | 1280 | 110 | 40 | 220 | 1650 |
| Vertical | 720 | 5 | 5 | 20 | 750 |

Pixel clock is 74.25 MHz. Both sync polarities are positive.

## Top-level interface

Instantiate `hdmi_720p` and add every `.sv` file in this folder to Vivado:

```systemverilog
logic [10:0] pixel_x;
logic [9:0]  pixel_y;
logic        pixel_de;
logic [15:0] game_rgb565;
logic        pixel_req;
logic [10:0] pixel_req_x;
logic [9:0]  pixel_req_y;

hdmi_720p #(
    .PIXEL_READ_LATENCY(1)
) hdmi (
    .pixel_clk      (pixel_clk_74m25),
    .pixel_clk_5x   (pixel_clk_371m25),
    .clocks_locked  (clock_wizard_locked),
    .reset          (reset),
    .pattern_sel    (2'd1),
    .rgb565         (game_rgb565),
    .solid_rgb565   (16'h001f),
    .pixel_x        (pixel_x),
    .pixel_y        (pixel_y),
    .pixel_de       (pixel_de),
    .frame_start    (),
    .pixel_req      (pixel_req),
    .pixel_req_x    (pixel_req_x),
    .pixel_req_y    (pixel_req_y),
    .hdmi_clk_p     (hdmi_clk_p),
    .hdmi_clk_n     (hdmi_clk_n),
    .hdmi_data_p    (hdmi_data_p),
    .hdmi_data_n    (hdmi_data_n)
);
```

`pattern_sel` selects the source:

| Value | Display |
|---:|---|
| `0` | External `rgb565` |
| `1` | Eight vertical color bars |
| `2` | `solid_rgb565` |
| `3` | 32x32-pixel checkerboard |

For integration with a game renderer or framebuffer, set `pattern_sel` to
zero. `pixel_req` requests the pixel at `pixel_req_x/pixel_req_y` in advance.
The corresponding `rgb565` must arrive exactly `PIXEL_READ_LATENCY` pixel
clocks later, when that location becomes `pixel_x/pixel_y`.

Set `PIXEL_READ_LATENCY` to the fixed read latency of the final pixel FIFO:

| FIFO configuration | Typical setting |
|---|---:|
| First-word fall-through (current `dout` is already valid) | 0 |
| Registered/synchronous `dout` | 1 |
| Extra output pipeline register | 2 |

Confirm the actual value from the generated FIFO IP configuration and its
simulation model.

## DDR3 MIG and framebuffer prefetch

Do not connect MIG read data directly to `rgb565`. MIG command and return
latency varies because of refresh, bank state and arbitration, while HDMI
must emit one pixel on every active pixel clock and cannot be paused.

Use this boundary:

```text
DDR3 framebuffer
      |
MIG burst reads (variable latency, e.g. 64/128 pixels per burst)
      |
asynchronous/FWFT pixel FIFO
      |
fixed FIFO read latency
      |
hdmi_720p rgb565
```

The DDR-side controller should:

1. Prefill the FIFO before enabling normal display.
2. Issue burst reads when FIFO occupancy falls below a low-water threshold.
3. Keep enough queued data to cover worst-case MIG refresh/arbitration delay.
4. Store pixels in raster order: `(0,0)` through `(1279,719)`.
5. Restart or swap the read base address only on a frame boundary.
6. Report FIFO underflow; an underflow is a system bandwidth/control error.

The HDMI timing generator starts in vertical blanking after reset rather than
at pixel `(0,0)`. This provides 30 blank lines, about 0.67 ms, for initial
FIFO prefill before the first visible frame.

If MIG uses `ui_clk` and HDMI uses `pixel_clk`, the FIFO must be an
asynchronous dual-clock FIFO. Writes occur in the MIG `ui_clk` domain and
reads occur in the 74.25 MHz `pixel_clk` domain.

## Connecting AXI VDMA

`hdmi_vdma_fifo_bridge.sv` connects the 16-bit RGB565 AXI VDMA MM2S video
stream to `hdmi_pixel_fifo`. It propagates FIFO backpressure through
`s_axis_tready`, checks `TUSER` start-of-frame and `TLAST` end-of-line
placement, and synchronizes a FIFO-prefilled indication into `pixel_clk`.

Connect:

```text
AXI VDMA M_AXIS_MM2S
    -> hdmi_vdma_fifo_bridge
    -> hdmi_720p rgb565
```

Hold `hdmi_720p.reset` asserted until `fifo_prefilled` is high. Instantiate
`hdmi_720p` with `PIXEL_READ_LATENCY=0`, because the contained FIFO uses FWFT
mode. Connect `stream_error_sticky` and `underflow_sticky` to an ILA or status
register.

## Connecting `hdmi_pixel_fifo` directly

`hdmi_pixel_fifo.sv` wraps a Vivado `xpm_fifo_async`. It uses block RAM and
FWFT mode. With this wrapper, instantiate HDMI with
`PIXEL_READ_LATENCY=0`:

```systemverilog
logic [15:0] fifo_pixel;
logic        fifo_pixel_valid;
logic        pixel_req;
logic        fifo_full;
logic        fifo_prog_full;
logic        fifo_underflow;

hdmi_pixel_fifo #(
    .FIFO_DEPTH(8192),
    .PROG_EMPTY_THRESHOLD(2048)
) framebuffer_fifo (
    .reset            (reset),

    // These three signals are in the MIG ui_clk domain.
    .wr_clk           (ui_clk),
    .wr_rgb565        (mig_pixel_rgb565),
    .wr_en            (mig_pixel_valid),
    .full             (fifo_full),
    .prog_full        (fifo_prog_full),
    .wr_data_count    (),

    // These signals are in the HDMI pixel_clk domain.
    .pixel_clk        (pixel_clk_74m25),
    .pixel_req        (pixel_req),
    .pixel_rgb565     (fifo_pixel),
    .pixel_valid      (fifo_pixel_valid),
    .empty            (),
    .prog_empty       (),
    .underflow        (fifo_underflow),
    .underflow_sticky ()
);

hdmi_720p #(
    .PIXEL_READ_LATENCY(0) // FIFO is configured as FWFT
) hdmi (
    .pixel_clk       (pixel_clk_74m25),
    .pixel_clk_5x    (pixel_clk_371m25),
    .clocks_locked   (clock_wizard_locked),
    .reset           (reset),
    .pattern_sel     (2'd0),
    .rgb565          (fifo_pixel_valid ? fifo_pixel : 16'h0000),
    .solid_rgb565    (16'h0000),
    .pixel_x         (pixel_x),
    .pixel_y         (pixel_y),
    .pixel_de        (pixel_de),
    .frame_start     (frame_start),
    .pixel_req       (pixel_req),
    .pixel_req_x     (),
    .pixel_req_y     (),
    .hdmi_clk_p      (hdmi_clk_p),
    .hdmi_clk_n      (hdmi_clk_n),
    .hdmi_data_p     (hdmi_data_p),
    .hdmi_data_n     (hdmi_data_n)
);
```

The MIG reader writes pixels only when `!fifo_full`. Prefer stopping new MIG
read commands at `fifo_prog_full`, while still allowing already outstanding
read responses to enter the remaining FIFO space. Size that reserved space
for the maximum number of outstanding MIG response beats.

An 8192-pixel FIFO stores about 6.4 display lines and consumes approximately
128 Kibit of BRAM. The 2048-pixel low-water mark is only a starting value;
final thresholds must be verified against the MIG UI width, burst length,
refresh delay and number of outstanding commands.

`underflow_sticky` should be connected to a debug register, LED, or ILA. If it
ever becomes one during normal display, increase prefetch depth/threshold or
fix the DDR read scheduler. Resetting the whole display path clears it.

### Startup sequence

Do not hold the FIFO in reset while trying to prefill it. Use separate FIFO
and HDMI reset conditions:

```text
1. Wait for MIG init_calib_complete.
2. Release framebuffer_fifo.reset.
3. Start burst reads and fill the FIFO.
4. Wait until wr_data_count reaches the chosen startup level.
5. Synchronize display_ready into the pixel_clk domain.
6. Release hdmi_720p.reset; visible scanning then begins after vertical blank.
```

For example, the board-level logic can conceptually use:

```systemverilog
fifo_reset = system_reset || !init_calib_complete;
hdmi_reset = system_reset || !display_ready_pixel_clk;
```

Synchronize `display_ready` with a normal two-flop synchronizer; do not pass
the multi-bit `wr_data_count` directly between clock domains.

RGB565 layout is:

```text
15          11 10             5 4           0
+--------------+----------------+-------------+
|    Red[4:0]  |   Green[5:0]   |  Blue[4:0] |
+--------------+----------------+-------------+
```

## Vivado Clocking Wizard

Configure one Clocking Wizard using the board's 50 MHz input:

| Port | Frequency |
|---|---:|
| Input | 50.000 MHz |
| `pixel_clk` | 74.250 MHz |
| `pixel_clk_5x` | 371.250 MHz |

Both outputs must come from the same Clocking Wizard so that their frequency
and phase relationship is controlled. Connect its `locked` output to
`clocks_locked`. Do not use two independent PLL/MMCM instances.

The serializer is DDR, so the 371.25 MHz clock produces a 742.5 Mbit/s stream
on each TMDS data lane.

## Vivado/XDC

Copy `constraints/templates/hdmi_pins_template.xdc` into the board project and replace every
`<...>` placeholder with the package pin from the board schematic or master
XDC. Do not guess HDMI pins.

The top module already instantiates `OBUFDS` with `TMDS_33`; the XDC repeats
the I/O standard so that the electrical requirement remains visible at the
board level.

## Scope

This is a DVI-compatible HDMI video stream. It intentionally does not
generate audio packets, infoframes, HDCP, EDID/I2C, or HDMI data islands.
Normal HDMI monitors accept this for uncompressed RGB video.

Clock generation is deliberately outside this reusable module. The board-level
top module should connect the 50 MHz oscillator to the Clocking Wizard and pass
the two generated clocks and `locked` into `hdmi_720p`.
