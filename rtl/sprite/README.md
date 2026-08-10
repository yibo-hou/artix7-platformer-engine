# Native 1280x720 Mario sprite engine

`sprite_engine.sv` is a coordinate-driven renderer for producing a native
1280x720 RGB565 framebuffer. There is no pixel replication or resolution
scaling. Its ready/valid interfaces allow a framebuffer writer to stop the
pipeline when its write FIFO or MIG path applies backpressure.

Features:

- one scrolling 128x64 tile layer;
- 64 available 16x16 tile images by default;
- 16 independently positioned 32x32 sprite slots;
- horizontal and vertical sprite flip;
- shared 16-color RGB565 palette;
- palette index zero transparency for sprites;
- higher sprite slot number has higher priority;
- pipelined one-pixel-per-clock rendering with output backpressure.

## Framebuffer/VDMA connection

`sprite_frame_stream.sv` generates `(0,0)` through `(1279,719)`, drives the
renderer request interface, and converts returned pixels to AXI4-Stream video.
Its stream connects to AXI VDMA `S_AXIS_S2MM`, which writes the rendered frame
to DDR3.

```systemverilog
logic        pixel_req;
logic [10:0] pixel_req_x;
logic [9:0]  pixel_req_y;
logic [15:0] rendered_rgb565;
logic        rendered_valid;
logic        rendered_ready;
logic [10:0] rendered_x;
logic [9:0]  rendered_y;

sprite_engine renderer (
    .pixel_clk          (pixel_clk_74m25),
    .reset              (video_reset),
    .pixel_req          (pixel_req),
    .pixel_req_x        (pixel_req_x),
    .pixel_req_y        (pixel_req_y),
    .pixel_req_ready    (pixel_req_ready),
    .rgb565             (rendered_rgb565),
    .rgb_valid          (rendered_valid),
    .rgb_ready          (rendered_ready),
    .rgb_x              (rendered_x),
    .rgb_y              (rendered_y),
    .rgb_frame_start    (),
    .rgb_frame_end      (),
    .scroll_x           (camera_x),
    .scroll_y           (camera_y),
    // Connect configuration ports to the future AXI-Lite wrapper.
    .tilemap_wr_en      (tilemap_wr_en),
    .tilemap_wr_addr    (tilemap_wr_addr),
    .tilemap_wr_tile    (tilemap_wr_tile),
    .tile_gfx_wr_en     (tile_gfx_wr_en),
    .tile_gfx_wr_addr   (tile_gfx_wr_addr),
    .tile_gfx_wr_index  (tile_gfx_wr_index),
    .sprite_gfx_wr_en   (sprite_gfx_wr_en),
    .sprite_gfx_wr_addr (sprite_gfx_wr_addr),
    .sprite_gfx_wr_index(sprite_gfx_wr_index),
    .sprite_attr_wr_en  (sprite_attr_wr_en),
    .sprite_attr_wr_slot(sprite_attr_wr_slot),
    .sprite_attr_wr_data(sprite_attr_wr_data),
    .palette_wr_en      (palette_wr_en),
    .palette_wr_index   (palette_wr_index),
    .palette_wr_rgb565  (palette_wr_rgb565)
);

sprite_frame_stream frame_source (
    .pixel_clk       (pixel_clk_74m25),
    .reset           (video_reset),
    .enable          (render_enable),
    .pixel_req       (pixel_req),
    .pixel_req_x     (pixel_req_x),
    .pixel_req_y     (pixel_req_y),
    .pixel_req_ready (pixel_req_ready),
    .rgb565          (rendered_rgb565),
    .rgb_valid       (rendered_valid),
    .rgb_ready       (rendered_ready),
    .rgb_x           (rendered_x),
    .rgb_y           (rendered_y),
    .m_axis_tdata    (vdma_s2mm_tdata),
    .m_axis_tkeep    (vdma_s2mm_tkeep),
    .m_axis_tvalid   (vdma_s2mm_tvalid),
    .m_axis_tready   (vdma_s2mm_tready),
    .m_axis_tuser    (vdma_s2mm_tuser),
    .m_axis_tlast    (vdma_s2mm_tlast),
    .frame_active    (),
    .frame_done      ()
);
```

`TUSER` marks the first pixel of a frame and `TLAST` marks the final pixel of
each line. VDMA applies backpressure with `TREADY`; that backpressure propagates
through `rgb_ready` and stalls all renderer stages without losing alignment.

The renderer does not instantiate MIG or assign DDR addresses. AXI VDMA S2MM
packs the stream into AXI bursts and selects the framebuffer configured by
Vitis. AXI VDMA MM2S reads an older framebuffer into
`hdmi_vdma_fifo_bridge`, which crosses into the HDMI pixel clock domain.

With `rgb_ready` continuously high, the renderer has fixed pipeline latency.
When `rgb_ready` is low, all stages stall together and latency grows without
losing or reordering pixels.

All engine configuration writes currently run in `pixel_clk`. Do not connect
an unrelated MicroBlaze AXI clock directly. Use an asynchronous command FIFO
or an AXI-Lite clock converter.

The internal tile and sprite memories intentionally infer distributed RAM
because the renderer needs asynchronous parallel reads. Sprite graphics are
split into one 1024x4-bit bank per sprite slot. Vivado AXI DMA reads assets
from DDR, and an AXI4-Stream Clock Converter crosses its MM2S stream into the
pixel-clock domain. `sprite_asset_unpacker.sv` serializes each stream beat into
the engine's narrow configuration writes. MIG latency therefore cannot stall
the active pixel pipeline.

## Memory formats

Tile-map address:

```text
tilemap_address = tile_y * 128 + tile_x
```

Tile-graphics address:

```text
tile_address = tile_id * 256 + local_y * 16 + local_x
```

Sprite-graphics address:

```text
sprite_address = sprite_slot * 1024 + local_y * 32 + local_x
```

Each graphics location contains a four-bit palette index. Index zero is
transparent for sprite pixels.

Sprite attributes are packed as:

| Bits | Meaning |
|---|---|
| 0 | enable |
| 11:1 | native X |
| 21:12 | native Y |
| 22 | flip X |
| 23 | flip Y |

Each slot owns its 32x32 bitmap. To animate Mario, load the new animation
frame into a disabled/unused slot, update its position, then change slot
enables during vertical blanking. A later version can add shadow attribute
registers with an atomic frame-boundary commit.

## AXI/Vitis integration

Three custom integration modules are provided:

- `sprite_engine_axi_lite.sv`: AXI4-Lite register bank and safe command CDC;
- `sprite_asset_unpacker.sv`: converts AXI DMA's MM2S stream into asset writes;
- `sprite_engine_config_mux.sv`: combines unpacker and control writes for the
  renderer.
- `sprite_frame_stream.sv`: generates complete AXI4-Stream video frames.

Add these Vivado IP blocks:

```text
MIG S_AXI <-- SmartConnect <-- MicroBlaze M_AXI
                         |-- AXI DMA M_AXI_MM2S
                         |-- AXI VDMA M_AXI_S2MM
                         `-- AXI VDMA M_AXI_MM2S

AXI DMA M_AXIS_MM2S
    -> AXI4-Stream Clock Converter
    -> sprite_asset_unpacker
    -> sprite_engine_config_mux
    -> sprite_engine

sprite_engine
    -> sprite_frame_stream
    -> AXI VDMA S_AXIS_S2MM

AXI VDMA M_AXIS_MM2S
    -> hdmi_vdma_fifo_bridge
    -> hdmi_720p
```

Configure AXI DMA for MM2S only, Simple mode, no Scatter-Gather, 256-bit
memory-map and stream widths, 32-bit addresses, maximum burst 16, no DRE.
Enable `TKEEP` and `TLAST` through the AXI4-Stream Clock Converter. DMA and
MIG use `ui_clk`; the converter output and unpacker use `pixel_clk`.

Configure AXI VDMA with both channels, three frame stores, a 16-bit RGB565
stream, 256-bit memory-map interfaces and dynamic genlock. Use S2MM as genlock
master and MM2S as genlock slave with a one-frame delay. Each frame has 720
lines, 2560 bytes per line and a 2560-byte stride.

The configuration mux gives the unpacker priority for palette writes. The
AXI-Lite slave holds a software palette transaction while asset unpacking is
busy, so the write is not discarded.

### AXI-Lite register map

| Offset | Name | Description |
|---:|---|---|
| `0x000` | CONTROL | write bit 0 = clear unpacker `done/error` status |
| `0x004` | STATUS | bit 1 unpacker busy, bit 2 done, bit 3 error, bit 4 config FIFO full |
| `0x008` | RENDER_CONTROL | bit 0 enables continuous framebuffer rendering |
| `0x00C` | ASSET_DEST | bits 31:30 kind, bits 15:0 destination item address |
| `0x014` | SCROLL | bits 10:0 X, bits 20:11 Y |
| `0x040-0x07C` | SPRITE_ATTR[0:15] | one packed attribute word per slot |
| `0x080-0x0BC` | PALETTE[0:15] | one RGB565 value per entry |

The matching Vitis definitions and inline helpers are in
`software/include/sprite_engine_regs.h`.

DMA destination kinds:

| Kind | Destination | DDR representation |
|---:|---|---|
| 0 | Tile map | one byte/item, low 6 bits used |
| 1 | Tile graphics | one byte/pixel, low 4 bits used |
| 2 | Sprite graphics | one byte/pixel, low 4 bits used |
| 3 | Palette | two little-endian bytes/RGB565 item |

Although four-bit graphics use only half of each source byte, the byte-based
asset format makes Vitis-side generation and DMA unpacking straightforward.
AXI DMA handles aligned bursts and 4 KiB boundaries. Because DRE is disabled,
keep source addresses 32-byte aligned. Transfer byte length can be shorter
than a complete beat; `TKEEP` tells the unpacker which final bytes are valid.

Example Vitis sequence:

```c
#include "sprite_engine_regs.h"
#include "xaxidma.h"

sprite_asset_set_destination(
    XPAR_SPRITE_ENGINE_AXI_LITE_0_S_AXI_BASEADDR,
    SPR_ASSET_SPRITE_GRAPHICS,
    0);                          /* sprite slot 0, pixel 0 */
sprite_asset_clear_status(
    XPAR_SPRITE_ENGINE_AXI_LITE_0_S_AXI_BASEADDR);

Xil_DCacheFlushRange(0x89000000u, 32u * 32u);
XAxiDma_SimpleTransfer(
    &AxiDma,
    0x89000000u,                 /* 32-byte-aligned DDR asset */
    32u * 32u,                   /* one byte per indexed pixel */
    XAXIDMA_DMA_TO_DEVICE);

while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) {
}

while (SPR_REG32(XPAR_SPRITE_ENGINE_AXI_LITE_0_S_AXI_BASEADDR,
                 SPR_STATUS_OFFSET) & SPR_STATUS_ASSET_BUSY) {
}
```

Program `ASSET_DEST` before starting AXI DMA and do not change it until both
AXI DMA and the unpacker are idle. Do not reset only one side of the AXI4-
Stream Clock Converter during a transfer.
