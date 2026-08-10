# Copper Hills game assets

This is an original platform-game asset set designed for the FPGA sprite
engine in this repository.

## Cast

### Hero: Red-cap explorer

The hero now uses a clean high-contrast 8-bit platformer silhouette. The
animation sheet contains:

```text
idle, blink, walk x4, run x3, jump rise, jump fall,
skid, crouch, hurt, victory, hatch interaction
```

Gameplay properties:

- 32x32 native sprite;
- run, jump and crouch;
- can activate reward blocks from below;
- receives one hit before respawning at the latest checkpoint;
- all 16 animation frames are cached in MicroBlaze BRAM at startup;
- the selected 1024-byte frame is uploaded through two alternating Sprite
  slots so runtime animation never waits for SD and never exposes a partial
  frame.

### Enemies

| Enemy | Frames | Behaviour |
|---|---:|---|
| Mushroom walker | 0-3 | Centered ground patrol |
| Green shell | 4-7 | Centered ground patrol |
| Night bat | 8-11 | Centered aerial patrol |
| Armored turtle | 12-15 | Slow centered patrol |

Enemy animation frames are stored sequentially in
`generated/enemies_32x32.bin`. Each frame is 1024 bytes.

## First map: Copper Hills

The first level is 128x64 tiles with a 16x16 tile size, covering a
2048x1024-pixel world. It introduces:

- simple platforms and reward blocks;
- three ground gaps;
- seamless two-tile-wide pipe obstacles using IDs 56-59 for left/right top
  and left/right body pieces;
- an elevated middle route;
- a checkpoint;
- spikes;
- two health pickups and two temporary-invincibility stars;
- five initial enemy placements;
- a goal marker near the right edge.

## Additional maps

`Sky Bridges` (`LEV02`) builds a smooth ascending/descending airborne route:

- staggered wooden bridges across four broad pits;
- a pipe garden with an optional high reward corridor;
- zig-zag sky islands and a final spike sprint;
- recovery lanes so a missed high-route jump does not always cost health.

`Starfall Run` (`LEV03`) is the faster, more technical course:

- alternating upper and lower paths with different risk/reward;
- an overhead stepping-stone route above a long spike corridor;
- increasingly tall pipe gates;
- a long late jump followed by a descending platform finale.

All three maps contain 34 coins so the fixed `COINS xx/34` HUD remains exact.
Each map has its own four enemy patrol ranges, two recovery/power items and a
grounded finish flag. Their SD-card files use the 8.3-compatible names
`LEV01.*`, `LEV02.*`, and `LEV03.*`.

`maps/level_01_tiles.bin` contains one tile ID byte per map cell in row-major
order. `maps/level_01_collision.bin` uses:

| Value | Meaning |
|---:|---|
| 0 | Empty |
| 1 | Solid |
| 2 | Hazard |
| 3 | Goal |
| 4 | Reward block |
| 5 | Collectible coin |
| 6 | Health pickup (+1, maximum 3) |
| 7 | Star pickup (about 5 seconds invulnerability) |

## Hardware formats

- Palette: 16 little-endian RGB565 values, 32 bytes total.
- Tile graphics: 64 frames, 16x16, one palette-index byte/pixel.
- Hero/enemy graphics: 16 frames per sheet, 32x32, one byte/pixel.
- Palette index zero: transparent for sprites and sky blue for tile output.
- All binary arrays use row-major pixel order.

The one-byte indexed format intentionally matches `sprite_asset_unpacker.sv`.
Only the low nibble is used for graphics.

## Included runtime assets

This public repository includes the pre-generated assets required by the
current MicroBlaze application. The `.bin` files under `sdcard/GAME/` are the
hardware payloads copied to the SD card; the files under `generated/` provide
matching previews and manifests. No Python image-processing package is needed
to build or run the FPGA project.
