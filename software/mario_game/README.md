# Experimental AXI-Lite/DMA game stack

> Status: reference implementation, not connected to the checked-in Vivado
> block design and not used to build the verified portfolio target.

This alternative Vitis application loads the Copper Hills assets from the FAT32 SD card,
uploads render resources through AXI DMA, configures AXI VDMA triple-buffered
framebuffers, runs collision/game logic at 60 Hz, and writes camera/sprite
state back to the hardware Sprite Engine.

Unlike the production application in `software/super_mario_game`, this stack
requires an AXI DMA instance and `sprite_engine_axi_lite`. The current block
design exposes renderer control through AXI GPIO instead. Keep the two
software-visible protocols separate unless the hardware is deliberately
migrated and revalidated.

## Per-frame ownership

```text
MicroBlaze software
    - keyboard input
    - fixed-point movement/gravity/jump
    - LEV01.COL collision queries
    - reward blocks/checkpoints/goal
    - enemy movement and player/enemy collision
    - camera and animation selection

Sprite Engine
    - tile lookup
    - sprite pixel lookup
    - transparency/priority/composition
    - RGB565 output
```

The software sends only state changes to the renderer:

- camera `scroll_x`;
- sprite enable, screen X/Y and horizontal flip;
- a 1024-byte sprite frame through AXI DMA when animation changes;
- an aligned 32-byte map region when a reward tile changes.

The collision map remains in DDR3 and is never sent to the renderer.

## Vitis source files

Add these directories to the application include/source paths:

```text
software/mario_game
software/common
software/sd_spi
software/include
```

Add `software/common/mario_framebuffer.c` to the application sources.

The BSP/application needs:

- MicroBlaze standalone BSP;
- FatFs headers/library;
- AXI Quad SPI (`XSpi`);
- AXI UART Lite (`XUartLite`);
- AXI DMA (`XAxiDma`);
- AXI VDMA (`XAxiVdma`);
- cache support.

Update the instance macros in `platform_config.h` if Vivado generated different
names.

## Linker memory placement

The six static asset buffers total about 68 KB and use the `.game_assets`
section. Place this section in MIG DDR3 in the Vitis linker script. The program
may execute from BRAM or DDR, but `.game_assets` must not be assigned to a
small local BRAM.

All buffers are 64-byte aligned. AXI DMA is configured without DRE, so the
source addresses satisfy its 32-byte alignment requirement.

## Vivado connections

```text
SD socket <-> AXI Quad SPI <-> MicroBlaze
UART input <-> AXI UART Lite <-> MicroBlaze

MicroBlaze M_AXI ----+
                     +-> SmartConnect -> MIG DDR3
AXI DMA M_AXI_MM2S --+

AXI DMA M_AXIS_MM2S
    -> AXIS Clock Converter
    -> sprite_asset_unpacker
    -> sprite_engine_config_mux
    -> sprite_engine

sprite_engine -> sprite_frame_stream -> AXI VDMA S_AXIS_S2MM
AXI VDMA M_AXIS_MM2S -> hdmi_vdma_fifo_bridge -> hdmi_720p

MicroBlaze AXI-Lite
    -> sprite_engine_axi_lite
    -> AXI VDMA
```

Connect `asset_status_clear` from `sprite_engine_axi_lite` to
`clear_status` on `sprite_asset_unpacker`.

## Controls

The existing host keyboard transmitter sends one byte continuously:

| Bit | Key | Action |
|---:|---|---|
| 0 | A | Move left |
| 1 | D | Move right |
| 2 | Space | Jump |

The Vitis loop drains AXI UART Lite and uses the newest state byte.

## Asset use

At boot:

1. Initialize the VDMA read/write channels and clear all three frame stores.
2. Initialize SD SPI and mount FAT32.
3. Read palette, tiles, hero, enemies, map and collision into DDR3.
4. Upload palette, all tile graphics and the level map.
5. Upload initial hero/enemy frames into sprite slots 0-5.
6. Enable continuous framebuffer rendering.
7. Begin the 60 Hz game loop.

Framebuffer addresses are `0x8C000000`, `0x8C200000` and `0x8C400000`.
Each reserves 2 MiB; one active RGB565 frame occupies 1,843,200 bytes.
Vivado must configure VDMA S2MM as dynamic-genlock master and MM2S as slave
with a one-frame delay.

Sprite slots:

| Slot | Use |
|---:|---|
| 0 | Hero |
| 1 | Clockwork beetle |
| 2 | Cave slime |
| 3 | Charcoal bat |
| 4 | Clockwork turtle |
| 5 | Second charcoal bat |
| 6-15 | Reserved |

The first level currently uses the five enemy placements defined by
`assets/maps/level_01.json`. They are represented as a compile-time table in
`mario_game.c`; tile and collision cells themselves are loaded from the SD
binary files.
