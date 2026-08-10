# Module descriptions

## Handwritten RTL

| Module | Location | Responsibility |
|---|---|---|
| `framebuffer_black_top` | `rtl/top` | Current integrated board top: MIG, block-design wrapper, sprite path, VDMA bridge, HDMI, SD/UART pins, HUD, resets, and debug |
| `hdmi_colorbar_top` | `rtl/top` | Minimal board target for clock, TMDS, and pin validation |
| `ddr3_axi_selftest_top` | `rtl/top` | Standalone MIG AXI write/read/compare FSM with LED status |
| `sprite_bringup_pattern` | `rtl/top` | Deterministic tile/palette/sprite initializer for renderer bring-up |
| `sprite_engine` | `rtl/sprite` | Stall-safe tile and sixteen-slot sprite compositor |
| `sprite_frame_stream` | `rtl/sprite` | Raster request generator and AXI4-Stream Video framing |
| `sprite_asset_unpacker` | `rtl/sprite` | Converts 256-bit asset DMA beats into narrow renderer-memory writes |
| `sprite_engine_axi_lite` | `rtl/sprite` | AXI4-Lite register bank and command crossing into `pixel_clk` |
| `sprite_engine_config_mux` | `rtl/sprite` | Arbitrates control-plane and bulk-loader writes |
| `hdmi_720p` | `rtl/hdmi` | Integrates timing, RGB source, TMDS channels, serializers, and OBUFDS outputs |
| `hdmi_tmds_encoder` | `rtl/hdmi` | DVI-compatible TMDS transition minimization and running-disparity encoding |
| `hdmi_tmds_serializer` | `rtl/hdmi` | Artix-7 master/slave OSERDESE2 10:1 DDR serializer |
| `hdmi_timing_720p` | `rtl/video` | 1280x720p60 counters, sync/de, frame marker, and look-ahead request |
| `hdmi_rgb565_source` | `rtl/video` | RGB565-to-RGB888 expansion and diagnostic pattern selection |
| `hdmi_vdma_fifo_bridge` | `rtl/video` | VDMA stream framing checks, FIFO backpressure, prefill, and error status |
| `hdmi_pixel_fifo` | `rtl/memory` | XPM asynchronous RGB565 FIFO between AXI and pixel clocks |
| `mario_title_overlay` | `rtl/top/framebuffer_black_top.sv` | Combinational title/menu overlay used by the integrated target |
| `game_hud_overlay` | `rtl/top/framebuffer_black_top.sv` | Combinational coin, health, power-up, win, and game-over overlay |

## Simulation

| Testbench | Coverage |
|---|---|
| `tb_sprite_frame_stream` | Raster order, SOF/EOL markers, and randomized-style downstream backpressure |
| `tb_sprite_asset_unpacker` | Byte ordering, partial final AXI beat, destination address progression, and completion |
| `tb_game_hud_overlay` | Background pass-through and HUD/banner pixel selection |

The tests are intentionally source-only. XSim work databases, generated
simulation wrappers, waveforms, and logs are excluded.

## Xilinx IP and Vivado sources

| IP/configuration | Purpose |
|---|---|
| MIG 7 Series | 512 MiB DDR3 controller with 256-bit AXI UI |
| MicroBlaze, MDM, LMB BRAM | Embedded control processor and local program/data memory |
| AXI SmartConnect | MicroBlaze, VDMA, and DDR3 connectivity |
| AXI VDMA | RGB565 frame writes and reads |
| AXI UART Lite | Keyboard-state input and diagnostic output |
| AXI Quad SPI | SD-card SPI transport |
| Clocking Wizard | Pixel and phase-related 5x serializer clocks |
| Processor System Reset | Domain-aware reset generation |
| ILA | Runtime inspection of MIG, VDMA, FIFO, HDMI, and SD signals |

The block design and `.xci` files under `vivado/Super_Mario.srcs/sources_1`
are configuration sources, not handwritten RTL. Vivado-generated wrappers and
IP output products are regenerated into ignored directories.

## Software

- `software/super_mario_game`: production board application and Vitis build
  automation used by the current verified hardware target.
- `software/mario_game`: experimental modular AXI-Lite/DMA controller stack
  with host-buildable unit-test stubs; its required hardware is not in the
  current block design.
- `software/sd_spi`: custom read-only SPI-mode SD block driver and FatFs
  `diskio` adapter.
- `software/include/sprite_engine_regs.h`: software-visible register contract
  for the reusable sprite-engine control path.
- `scripts/host`: PC UART keyboard transmitter and bounded UART capture tool.
- `assets/`: pre-generated renderer graphics, maps, and SD-card payloads used by
  the current application. Asset-generation tooling is not included in this
  public copy.

See `software/README.md` for the support status and hardware dependency of
each application.

## Important implementation distinction

The renderer and video transport are RTL. The game rules are primarily C on
MicroBlaze. Portfolio descriptions should say “hardware-accelerated sprite and
video pipeline with an embedded game controller,” rather than claiming that
all gameplay is an RTL FSM.
