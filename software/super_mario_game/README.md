# Integrated MicroBlaze game runtime

This is the production software for the verified `framebuffer_black_top`
hardware target. MicroBlaze runs the three-level game, keyboard input,
collision and enemy logic, animation, HUD state, SD-card loading, and VDMA
control. RTL performs sprite/tile rendering, frame streaming, video timing,
TMDS encoding, and DDR-facing transport.

At startup the application holds the renderer stopped, clears three RGB565
frame stores, starts S2MM, releases the renderer at SOF, and then starts MM2S:

```text
Sprite Engine -> VDMA S2MM -> DDR3 -> VDMA MM2S -> async FIFO -> HDMI 720p
```

Memory map:

- BRAM: `0x00000000`, 128 KiB
- AXI UART Lite: `0x40600000`
- renderer-control AXI GPIO: `0x41200000`
- AXI VDMA registers: `0x44A00000`
- DDR3: `0x80000000` through `0x9fffffff`
- gameplay frame stores: `0x8c000000`, `0x8c200000`, `0x8c400000`
- CPU-drawn level-select stores: `0x8c600000`, `0x8c800000`, `0x8ca00000`

UART is 115200 baud, 8 data bits, no parity, one stop bit.

The 32-bit renderer-control GPIO is committed by the pixel-clock domain only
at a completed render-frame boundary:

- bit 0: run the renderer;
- bit 1: enable the hero;
- bits 11:2: hero screen X divided by two;
- bits 20:12: hero Y divided by two;
- bits 29:21: camera X divided by two;
- bit 30: active hero image slot;
- bit 31: flip the hero horizontally.

`HERO.BIN` supplies idle, blink, four walking, jump-rise, jump-fall, and
victory frames. All 16 frames are cached in the 128 KiB MicroBlaze BRAM during
startup, so gameplay never waits for the 390.625 kHz SD link. Two 32x32 Sprite
image slots are used as a display/upload pair: a new frame is copied only into
the inactive slot, then selected atomically at the next render-frame boundary.
This prevents partially uploaded animation frames from appearing on HDMI.

The post-framebuffer HDMI overlay always shows `COINS xx/34`. Touching the
goal latches a centered `LEVEL CLEAR` banner and selects the victory frame.
When health reaches zero, input is locked for two seconds, the hero alternates
between hurt/crouch frames, and a centered `GAME OVER` panel remains visible
before health and the spawn position are reset.

Enemies advance only once every three 60 Hz game ticks. Two health pickups
restore one of the three health cells, while two star pickups grant 300 game
ticks (about five seconds) of invulnerability. During star power the hero
flashes, enemy damage is ignored, hazard respawns do not consume health, and
the top-center HUD displays `STAR`. Each pickup clears its map and collision
cell immediately, so it can only be collected once per boot. A health pickup
is deliberately left in place when the health bar is already full.

The current application uses each S2MM frame-complete flag as its 60 Hz game
tick. It drains the newest UART keyboard byte, applies horizontal movement,
jump velocity and gravity, and submits one atomic position update. Controls
use the same protocol as the full game:

- A / bit 0: move left;
- D / bit 1: move right;
- Space / bit 2: jump.

At boot, MicroBlaze first draws a three-card level selector directly into its
own DDR framebuffer set. MM2S displays this menu independently while the SD
card is verified. Use A/D to select `COPPER HILLS`, `SKY BRIDGES`, or
`STARFALL RUN`, then press Space. The menu changes to `LOADING` while the
chosen map, collision layer and sprite assets are uploaded. MM2S then switches
atomically to the normal S2MM-generated triple buffer with dynamic genlock.

Run the host transmitter after the USB-UART port appears:

```bash
python3 scripts/host/keyboard_uart.py --list
python3 scripts/host/keyboard_uart.py /dev/ttyUSB0
```

Click the control window before using A/D/Space. This focused-window approach
does not require root access on Linux. `--neutral` skips the window and sends
only the released state for UART/VDMA diagnostics.

The transmitter also prints MicroBlaze TX output. A valid run keeps LED3 off
and periodically reports `Interactive OK` with changing input, X and Y values.
If input bytes stop arriving, the MicroBlaze releases all controls after 15
rendered frames so a disconnected host cannot leave movement stuck on.

Build the application after exporting the hardware XSA:

```bash
XILINX_VITIS_DATA_DIR=/tmp/super_mario_vitis_data \
  vitis -s software/super_mario_game/build.py
vivado -mode batch -source scripts/vivado/embed_framebuffer_black_elf.tcl
```

The first command creates `build/framebuffer_black/super_mario_game.elf`.
The second inserts that ELF into the implemented MicroBlaze BRAM and creates
`build/framebuffer_black/framebuffer_black_top.bit`. Do not program
`framebuffer_black_hw.bit`: it still contains only the generated MicroBlaze
boot loop.
