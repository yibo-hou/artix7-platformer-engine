# CF7A100B Standalone HDMI Color-Bar Test

This test uses the existing `Super_Mario.xpr`; it does not create a second Vivado project. It uses an independent constraint set and run set:

- Top level: `hdmi_colorbar_top`
- Constraint set: `colorbar_constrs`
- Synthesis run: `colorbar_synth`
- Implementation run: `colorbar_impl`

The test path does not include MIG, MicroBlaze, VDMA, the asynchronous FIFO, or the Sprite Engine:

```text
50 MHz board clock
    -> Clocking Wizard
    -> 720p timing and color bars
    -> TMDS encoding/serialization
    -> HDMI_B OUT
```

It therefore verifies only the HDMI output chain, not the DDR3 end-to-end path.

## Generated bitstream

```text
build/hdmi_colorbar/hdmi_colorbar_top.bit
```

Current implementation results:

- FPGA: `XC7A100T-2FGG484`
- Pixel clock: 74.21875 MHz
- TMDS serializer clock: 371.09375 MHz
- Output: 1280×720 at approximately 59.975 Hz
- DRC: 0 errors
- WNS: 7.495 ns
- WHS: 0.178 ns

The 74.21875 MHz clock is the closest value that the Vivado Clocking Wizard can generate from the 50 MHz board clock. The error is approximately -0.042%, while the pixel-to-serializer clock ratio remains exactly 1:5.

## Board programming

1. Connect the display to the development board's **HDMI_B OUT** connector, not the HDMI_A input.
2. Connect JTAG and power on the board.
3. In Vivado Hardware Manager, select Open Target → Auto Connect.
4. Select Program Device and load `build/hdmi_colorbar/hdmi_colorbar_top.bit`.
5. Release the reset button. The display should report 1280×720 and show eight vertical bars: white, yellow, cyan, green, magenta, red, blue, and black.

LEDs provide a quick status check:

| LED | Meaning | Expected state |
|---|---|---|
| LED0 | HDMI Clocking Wizard locked | On |
| LED1 | Frame heartbeat | Slow blink |
| LED2 | Board reset released | On |
| LED3 | Reserved fault indicator | Off |

If LED0 is off, check the 50 MHz clock and reset first. If LED0 and LED2 are on but there is no video, confirm HDMI_B OUT and record the monitor-reported resolution and all four LED states.

## Recreate and build

Run from the repository root:

```bash
vivado -mode batch -source scripts/vivado/create_hdmi_colorbar_test.tcl
vivado -mode batch -source scripts/vivado/build_hdmi_colorbar_test.tcl
```

Detailed reports are written to `build/hdmi_colorbar/reports/`.

## Standalone DDR3 AXI self-test

After the color-bar test passes, use the following bitstream to verify the MIG independently:

```text
build/ddr3_selftest/ddr3_axi_selftest_top.bit
```

After MIG calibration, the test writes 32 KiB of known data through the 256-bit AXI interface, reads it back for comparison, then cycles through additional patterns. It does not include MicroBlaze, VDMA, or HDMI.

| LED | Meaning | Expected state |
|---|---|---|
| LED0 | `init_calib_complete` | On |
| LED1 | MIG `ui_clk` and self-test heartbeat | Continuous blink |
| LED2 | At least one write/read comparison passed | On |
| LED3 | AXI response or data-compare error latched until reset | Off |

The expected result is `LED0=on, LED1=blinking, LED2=on, LED3=off`. Run for at least 10 minutes and press reset several times to confirm that calibration and the test restart cleanly.

Recreate and build:

```bash
vivado -mode batch -source scripts/vivado/create_cf7a100b_mig.tcl
vivado -mode batch -source scripts/vivado/create_ddr3_selftest.tcl
vivado -mode batch -source scripts/vivado/build_ddr3_selftest.tcl
```

DDR3 self-test reports are written to `build/ddr3_selftest/reports/`.

## Minimal DDR3 framebuffer loop

After the DDR3 AXI self-test passes, use the following bitstream to verify the complete read/display path:

```text
MicroBlaze clears three RGB565 framebuffers
    -> AXI VDMA MM2S
    -> 8192-pixel asynchronous FIFO
    -> Existing HDMI 720p output
```

The board-programmable file is:

```text
build/framebuffer_black/framebuffer_black_top.bit
```

Do not select `framebuffer_black_hw.bit`; it does not contain the embedded MicroBlaze clear-screen program. The display should report 1280×720 and show stable black active video. Because a black image resembles no signal, check both the monitor OSD and the LEDs:

| LED | Meaning | Expected state |
|---|---|---|
| LED0 | MIG `init_calib_complete` | On |
| LED1 | MIG UI-clock heartbeat | Continuous blink |
| LED2 | VDMA filled the asynchronous FIFO to its prefill level and HDMI was released | On |
| LED3 | FIFO underflow or AXI4-Stream frame/line marker error (latched) | Off |

USB-UART is 115200, 8N1. A normal boot log should contain:

```text
Super Mario FPGA game runtime
Clearing three 1280x720 RGB565 frames...
DDR3 clear complete
VDMA MM2S started
MM2S status: 0x...
```

The first clear writes approximately 5.3 MiB of DDR3, so a short wait may be needed before LED2 lights and HDMI becomes active. If LED0 is on but LED2 remains off, capture the MM2S status from UART. If LED2 and LED3 are both on, check FIFO read/write rates and VDMA `TUSER`/`TLAST`.

Recreate the complete result:

```bash
vivado -mode batch -source scripts/vivado/create_framebuffer_black_bd.tcl
vivado -mode batch -source scripts/vivado/create_framebuffer_black_target.tcl
vivado -mode batch -source scripts/vivado/build_framebuffer_black.tcl
XILINX_VITIS_DATA_DIR=/tmp/super_mario_vitis_data \
  vitis -s software/super_mario_game/build.py
vivado -mode batch -source scripts/vivado/embed_framebuffer_black_elf.tcl
```

The clean-checkout hardware rebuild on 2026-08-09 is recorded in `build/framebuffer_black/reports/`: DRC 0 errors, WNS `+0.848 ns`, WHS `+0.014 ns`, and all bus-skew constraints passed. That validation produced the hardware bitstream, LTX, and XSA, but did not rebuild or embed the Vitis game ELF.

## Sprite Engine S2MM loop

After the black-frame and color-bar read paths pass, the current target can also exercise the complete renderer loop:

```text
Sprite Engine -> VDMA S2MM -> DDR3 -> VDMA MM2S -> FIFO -> HDMI 720p
```

MicroBlaze controls the rendering stream through the 32-bit AXI GPIO at `0x41200000`. GPIO is held at zero at power-on and is set only after S2MM is fully configured and leaves Halted, guaranteeing that the first pixel received by VDMA is `(0,0)` and avoiding the startup `S2MM_DMASR[8]` short-line error.

Expected UART milestones are:

```text
S2MM ready; enabling loaded level at SOF
S2MM first frame complete: SR=0x00011000
VDMA MM2S started
```

`0x1000` is the normal frame-complete interrupt, not a fault.

### SD map collision and horizontal scrolling

The application loads the 8192 collision cells from `GAME/LEV01.COL` into MicroBlaze BRAM and updates actor state on each S2MM frame-complete event:

- `1` and `4` block the actor (solid tile and reward block, respectively).
- `2` respawns at `(48,640)`.
- `3` prints a goal-reached message on UART.
- `5` is a coin; collecting it removes the tile and increments the counter.
- `6` is a health item; collecting it restores one health cell, up to three.
- `7` is an invincibility star; collecting it grants approximately five seconds of invulnerability, with a blinking actor and `STAR` HUD indicator.
- After world coordinate `x=400`, the camera follows to the right, up to `x=768`.

The current Copper Hills map contains 34 coins arranged across tutorial climbing, pipe timing, bridge jumps, high steps, and a spike finale. Coin placement also provides recommended jump trajectories. The fixed HDMI HUD shows `COINS xx/34`; reaching the goal latches `LEVEL CLEAR` and prints `coins=collected/34` on UART. The full goal-pole column triggers the clear, with an additional world-coordinate guard so the message is not skipped when jumping over the pole. Pipes use four composable tiles (left/right cap and left/right body), and the sky, ground, and brick textures are seamless.

The fixed upper-right HUD shows three red health cells. Contact with a patrol enemy, a spike, or a pit removes one cell and respawns the actor. When health reaches zero, UART prints `GAME OVER`, the display shows a two-second failure animation, and the actor then respawns with full health. Four independent hardware sprites move in the level: beetle, slime, bat, and turtle. Enemy positions update every three game frames at approximately one third of the former speed, leaving time to observe and jump. The map also contains two health items and two invincibility stars; collected items are removed from both the collision table and Tile Map to prevent duplicate pickup.

The control GPIO bitfield is: bit 0 run, bit 1 hero enable, bits 11:2 `screen_x/2`, bits 20:12 `y/2`, bits 29:21 `camera_x/2`, bit 30 selects the active sprite image slot, and bit 31 controls horizontal flip. FPGA logic latches actor attributes and camera position at the frame boundary so the tile and sprite layers cannot use different state within one frame.

### Hero animation

At startup, MicroBlaze loads the 16 32×32 frames from `GAME/HERO.BIN` into 128 KiB of local BRAM. Runtime animation no longer reads from the slower SD SPI path. Two sprite image slots provide double buffering: while one slot is displayed, software rewrites the other from BRAM; after the write completes, bit 30 switches slots at a frame boundary, preventing a partially updated image from being displayed. The current state selection is:

- Idle displays the idle frame and periodically changes to blink.
- Ground movement cycles walk 0 through walk 3.
- Rising displays jump-rise; falling displays jump-fall.
- Pressing Space again in the air enables a second jump.
- Moving left uses bit 31 to mirror the same artwork.
- Reaching the goal displays the victory frame and keeps the completion message on screen.

UART prints once every 256 frames:

```text
Interactive OK: frames=... input=... world_x=... screen_x=... y=... camera=... anim=... bank=... flip=...
```

### LED2 does not light

If LED0 and LED1 are normal but LED2 remains off and there is no video, the FIFO has not received enough MM2S pixels, so HDMI remains in reset by design. First confirm that the programmed `framebuffer_black_top.bit` uses MM2S Genlock Master mode and disables the internal S2MM Genlock that is not present in this design.

If LED2 still does not light, copy the complete UART log. The current log prints VDMA `CR` and `SR` before and after startup; the return value after `VDMA start failed` distinguishes reset timeout, AXI error, and a channel that remains Halted.
