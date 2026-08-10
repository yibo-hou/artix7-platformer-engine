# SD card SPI driver for Vitis

`sd_spi.c` is a read-only SD-card SPI-mode driver for MicroBlaze/Vitis. It
uses the Xilinx `XSpi` driver for an AXI Quad SPI instance and supports SDSC,
SD v2, and SDHC cards.

The driver implements the required SPI startup sequence:

```text
CS high + 80 clocks
CMD0
CMD8
CMD55 + ACMD41 loop
CMD58
CMD16 for non-SDHC cards
CMD17 block reads
```

## Vivado IP configuration

Create an **AXI Quad SPI** IP instance:

| Option | Value |
|---|---|
| Mode | Standard SPI |
| Master mode | Enabled |
| Number of slave-selects | 1 |
| Transaction width | 8 bits |
| FIFO | Enabled, 16 or 256 entries |
| CPOL/CPHA | 0/0, SPI mode 0 |
| AXI clock | `ui_clk` or another MicroBlaze-accessible clock |

`C_SCK_RATIO` is an IP-generation parameter, not a run-time setting. For a
strict SD-spec startup using this one fixed-clock AXI Quad SPI core, choose a
clock at or below 400 kHz and keep it there. That is adequate for this 68 KB
asset pack. If faster post-initialization reads are needed, use a second,
programmable-clock SPI implementation; do not raise a fixed AXI Quad SPI
clock above the card's initialization limit before CMD0/ACMD41 complete.

Connect pins:

```text
SD_CS    <- ss[0]
SD_CLK   <- sck
SD_MOSI  <- io0_o
SD_MISO  -> io1_i
```

Use a 3.3 V microSD socket and board pull-ups specified by its schematic.

## Vitis setup and use

Add `sd_spi.c` and `sd_spi.h` to the Vitis application. The BSP must include
the AXI Quad SPI driver (`xspi.h`). Replace the device ID with the value from
`xparameters.h`.

```c
#include "sd_spi.h"
#include "xparameters.h"

sd_spi_t sd;
u8 sector[512];

if (sd_spi_init(&sd, XPAR_AXI_QUAD_SPI_0_DEVICE_ID) != SD_SPI_OK) {
    /* card/wiring/IP configuration error */
}

if (sd_spi_read_blocks(&sd, 0, sector, 1) != SD_SPI_OK) {
    /* read failure */
}
```

`sd_spi_read_blocks()` uses CMD17 once per block. This is deliberately simple
and robust for initial FAT32 bring-up. It is sufficient for level/asset loads;
CMD18 multi-block reads can be added after the card and filesystem path are
validated.

This module reads raw logical blocks. To load `GAME/HERO.BIN` by file name,
use FatFs above this layer. `sd_spi_diskio.c` is the supplied read-only FatFs
bridge. Add it to the Vitis application **instead of** any other `diskio.c`,
then bind the initialized driver before mounting:

```c
#include "ff.h"
#include "sd_spi_diskio.h"

FATFS fatfs;
sd_spi_diskio_bind(&sd);
if (f_mount(&fatfs, "0:", 1) != FR_OK) {
    /* FAT32 filesystem not mounted */
}
```

The bridge supports `disk_read()` only; write attempts return write-protected.
That is intentional for immutable game assets.
