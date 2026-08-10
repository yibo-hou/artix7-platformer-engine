# Hardware interfaces

## Board and device

The target is the ALIENTEK DaVinci Pro CF7A100B with an
`XC7A100T-2FGG484` Artix-7. Pin assignments in `constraints/` are specific to
this board. Do not reuse them on another Artix-7 board without checking the
schematic, I/O-bank voltage, clock-capable pins, and differential pairs.

## External interfaces

| Interface | RTL ports | Configuration |
|---|---|---|
| System clock | `sys_clk_i` | 50 MHz, pin R4, LVCMOS15 |
| Reset | `sys_rst_n` | Active low, pin U7, LVCMOS15 |
| HDMI_B output | `tmds_clk_p/n`, `tmds_data_p/n[2:0]` | TMDS_33, 720p60 video only |
| USB-UART | `uart_rxd`, `uart_txd` | 115200 baud, 8N1, LVCMOS33 |
| SD card | `sd_miso`, `sd_mosi`, `sd_clk`, `sd_cs` | SPI mode, LVCMOS33; MISO/CS pulled up |
| DDR3 | `ddr3_*` | 32-bit data, 1.5 V SSTL, pin/timing data from MIG `.prj` |
| Status LEDs | `led[3:0]` | Pins V9/Y8/Y7/W7, LVCMOS15 |
| JTAG | Dedicated pins | Vivado Hardware Manager, MicroBlaze debug, ILA |

The HDMI transmitter emits DVI-compatible video symbols. It does not implement
audio, data islands, EDID, HDCP, or HDMI InfoFrames.

## Video timing

| Parameter | Active | Front porch | Sync | Back porch | Total |
|---|---:|---:|---:|---:|---:|
| Horizontal pixels | 1280 | 110 | 40 | 220 | 1650 |
| Vertical lines | 720 | 5 | 5 | 20 | 750 |

Both sync polarities are positive. Internal pixels are RGB565; channels are
expanded to RGB888 by bit replication before TMDS encoding.

## UART keyboard protocol

The host sends the current key state as one byte at approximately 60 Hz:

| Bit | Key | Meaning |
|---:|---|---|
| 0 | A | Move left |
| 1 | D | Move right |
| 2 | Space | Jump/select |
| 7:3 | — | Reserved, transmit as zero |

MicroBlaze drains all available bytes and uses the newest state. The integrated
application releases the controls if updates stop, avoiding stuck movement
after a host disconnect.

## SD-card interface

The custom driver initializes the card at approximately 390.625 kHz and uses
SPI-mode block reads. `sd_spi_diskio.c` exposes a read-only FatFs disk layer;
write operations intentionally report write-protected. The `assets/sdcard`
tree is the content to copy to a FAT32 card.

## DDR3 and frame buffers

Two Nanya `NT5CC128M16IP-DI` x16 devices form a 32-bit, 512 MiB memory. MIG
runs the memory at 400 MHz (800 MT/s) and exposes a 100 MHz, 256-bit AXI UI.
The nominal peak physical bandwidth is 3.2 GB/s.

| Region | Base address | Notes |
|---|---:|---|
| MicroBlaze DDR window | `0x8000_0000` | Program/data window when used |
| Frame buffer 0 | `0x8C00_0000` | 2 MiB reservation |
| Frame buffer 1 | `0x8C20_0000` | 2 MiB reservation |
| Frame buffer 2 | `0x8C40_0000` | 2 MiB reservation |
| Menu frame stores | `0x8C60_0000` onward | Three CPU-drawn level-select frames |

The linker script, heap, stack, and frame stores must remain non-overlapping.
The production application caches hero animation in MicroBlaze BRAM and loads
renderer assets directly from SD through the AXI-GPIO command protocol; it
does not reserve a fixed DDR asset-staging region.

## Integrated AXI peripheral map

The current bring-up application uses these addresses:

| Peripheral | Base address |
|---|---:|
| AXI UART Lite | `0x4060_0000` |
| Renderer-control GPIO | `0x4120_0000` |
| AXI VDMA | `0x44A0_0000` |
| AXI Quad SPI | `0x44A1_0000` |

The renderer GPIO is sampled in the pixel domain and committed on a completed
render-frame boundary. Its packed fields are documented in
`software/super_mario_game/README.md`.

## Status and debug

LED meanings differ by target. The standalone HDMI target indicates clock
lock/frame heartbeat/reset; the DDR3 self-test indicates calibration,
heartbeat, pass, and sticky error; the integrated target indicates MIG/FIFO
readiness and sticky stream/underflow errors. Consult
[bringup.md](bringup.md) before interpreting the LEDs.
