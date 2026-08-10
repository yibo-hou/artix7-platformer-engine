SUPER MARIO FPGA SD CARD RESOURCE DIRECTORY

Copy the GAME directory to a FAT32-formatted SD or microSD card.

GAME/PAL565.BIN   16-entry RGB565 palette
GAME/TILES.BIN    64 x 16x16 indexed tiles
GAME/HERO.BIN     16 x 32x32 hero frames
GAME/ENEMY.BIN    16 x 32x32 enemy frames
GAME/LEV01.MAP    128x64 tile IDs
GAME/LEV01.COL    128x64 collision values
GAME/LEV01.JSN    level metadata and enemy placements
GAME/LEV02.MAP    Sky Bridges 128x64 tile IDs
GAME/LEV02.COL    Sky Bridges collision values
GAME/LEV02.JSN    Sky Bridges metadata and enemy placements
GAME/LEV03.MAP    Starfall Run 128x64 tile IDs
GAME/LEV03.COL    Starfall Run collision values
GAME/LEV03.JSN    Starfall Run metadata and enemy placements
GAME/MANIFEST.JSN asset metadata

All binary files use row-major order. Graphics use one byte per palette
index. RGB565 values are little endian.
