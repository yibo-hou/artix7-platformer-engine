# DDR3 MIG AXI configuration contract

Use these settings when generating the 7-Series MIG IP. The RTL and future
Vitis address map will assume this configuration.

## Physical/controller settings

| Setting | Value |
|---|---|
| Memory type | DDR3 SDRAM, Components |
| Memory component | `NT5CC128M16IP-DI` (two components, custom MIG part) |
| Physical data width | 32 bits (two x16 components) |
| Total capacity | 512 MiB |
| Memory clock period | 2500 ps / 400 MHz |
| PHY-to-controller ratio | 4:1 |
| Controller/UI clock | 100 MHz |
| DDR transfer rate | 800 MT/s |
| Theoretical peak bandwidth | 3.2 GB/s |
| Burst type/length | Sequential BL8 |
| ECC | Disabled |
| Data mask | Enabled |
| Bank machines | 4 |
| Ordering | Normal |
| Address mapping | Bank-Row-Column |
| ODT/driver settings | Use the board vendor's known-good values |

This board is confirmed to use two Nanya `NT5CC128M16IP-DI` devices. MIG uses
`MT41J128M16XX-125` only as the base part required by the custom-part dialog,
then overrides the geometry and timing with the Nanya values from the
CF7A100B board manual.

| Custom timing | Value |
|---|---:|
| `tCKE` | 5.625 ns |
| `tFAW` | 45 ns |
| `tRAS` | 36 ns |
| `tRCD` | 13.5 ns |
| `tREFI` | 7.8 us |
| `tRFC` | 160 ns |
| `tRP` | 13.5 ns |
| `tRRD` | 7.5 ns |
| `tRTP` | 7.5 ns |
| `tWTR` | 7.5 ns |

The custom geometry is 14 row bits, 10 column bits and 3 bank bits.

## AXI parameters

| Setting | Value |
|---|---|
| Interface | AXI4 |
| MIG AXI address width | 29 bits |
| AXI data width | 256 bits |
| AXI ID width | 4 bits |
| Narrow burst support | Enabled |
| Read/write arbitration | Round-Robin |
| Base address | `0x8000_0000` |
| High address | `0x9FFF_FFFF` |
| Address-space size | 512 MiB |

The 256-bit AXI width matches the native 4:1 UI width for a 32-bit physical
DDR interface. Each full-width AXI beat transfers 32 bytes. Full-width DMA
addresses must therefore be 32-byte aligned.

Narrow bursts remain enabled because MicroBlaze and control software can issue
32-bit accesses. AXI DMA should use full-width, aligned INCR bursts.

## Clock and reset

The CF7A100B system clock is a 50 MHz single-ended clock. It is buffered once
at the system top level and drives the MIG `sys_clk_i`. A separate MMCM derives
the 200 MHz `clk_ref_i` required by MIG's IDELAYCTRL. Both MIG clock inputs are
therefore configured as `No Buffer`. The board-level package pin is `R4` with
`LVCMOS15`.

```text
50 MHz board oscillator --> shared IBUF/BUFG --+--> MIG sys_clk_i
                                               |
                                               +--> MMCM --> 200 MHz clk_ref_i
                                               |
                                               `--> HDMI clock generation
```

Do not select `Use System Clock` as MIG's reference-clock mode when
`InputClkFreq` is 50 MHz: IDELAYCTRL requires 200 MHz.

MIG produces `ui_clk`, expected to be 100 MHz for the selected 400 MHz/4:1
configuration. The MIG AXI interface and AXI interconnect connected directly
to it operate in this `ui_clk` domain.

Use the actual generated MIG port list as the authority for clock and reset
connections. The CF7A100B configuration uses `sys_clk_i` on `R4` and an
active-low `sys_rst` driven from the board `sys_rst_n` input on `U7`.

Do not release DDR clients until `init_calib_complete` is asserted. Generate
the AXI active-low reset with Processor System Reset using `ui_clk` and the
MIG calibration/lock status.

## System architecture

```text
MicroBlaze M_AXI ------------------+
AXI DMA M_AXI_MM2S ----------------+
AXI VDMA M_AXI_S2MM ---------------+--> AXI SmartConnect --> MIG S_AXI
AXI VDMA M_AXI_MM2S ---------------+                         |
                                                              DDR3

SD assets in DDR3 -> AXI DMA -> asset unpacker -> local renderer memories

sprite engine -> frame stream -> VDMA S2MM -> DDR3 frame stores
DDR3 frame stores -> VDMA MM2S -> asynchronous pixel FIFO -> HDMI
```

DDR3 is the framebuffer boundary. The renderer produces complete RGB565
frames; VDMA S2MM writes them with AXI bursts. VDMA MM2S independently
prefetches an older frame into an asynchronous FIFO so MIG refresh and
arbitration cannot interrupt HDMI's fixed pixel rate.

Use three frame stores and VDMA dynamic genlock. Configure S2MM as genlock
master and MM2S as slave delayed by one completed frame. This prevents the
display channel from reading the frame currently being rendered.

## Address plan

The production GPIO-controlled application reserves only the frame stores
below. Earlier AXI-DMA experiments proposed fixed asset staging regions, but
those addresses are not part of the checked-in integrated implementation.

| Region | Start | Suggested maximum |
|---|---:|---:|
| MicroBlaze program/data | `0x8000_0000` | project-defined |
| Framebuffer 0 | `0x8C00_0000` | 2 MiB |
| Framebuffer 1 | `0x8C20_0000` | 2 MiB |
| Framebuffer 2 | `0x8C40_0000` | 2 MiB |

These are byte addresses. Final linker regions and asset sizes must not
overlap. Keep DMA objects at least 32-byte aligned.
