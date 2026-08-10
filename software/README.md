# Software layout

The checked-in applications do not all target the same hardware configuration.

| Directory | Status | Purpose |
| --- | --- | --- |
| `super_mario_game` | Production | Complete three-level MicroBlaze game used by the verified `framebuffer_black_top`; controls the renderer through AXI GPIO |
| `framebuffer_bringup` | Diagnostic | Small VDMA/framebuffer experiment that reuses the shared framebuffer helper |
| `mario_game` | Experimental | Modular AXI-Lite + AXI DMA alternative; its required hardware is not instantiated in the current block design |
| `sd_spi` | Shared driver | Read-only SD SPI and FatFs disk-I/O integration |
| `common` | Shared helper | VDMA framebuffer setup reused by diagnostic and experimental applications |
| `include` | Experimental interface | Register definitions for the reusable AXI-Lite sprite-control path |

For the public portfolio build, start with `super_mario_game`. The experimental
stack is retained as design-development evidence, not as a second supported
firmware image for the current bitstream.
