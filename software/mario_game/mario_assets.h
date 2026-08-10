#ifndef MARIO_ASSETS_H
#define MARIO_ASSETS_H

#include "ff.h"
#include "xaxidma.h"
#include "xil_types.h"

#define MARIO_TILE_COUNT           64U
#define MARIO_TILE_BYTES           (64U * 16U * 16U)
#define MARIO_SPRITE_FRAME_BYTES   (32U * 32U)
#define MARIO_SPRITE_FRAME_COUNT   16U
#define MARIO_SPRITE_SHEET_BYTES   \
    (MARIO_SPRITE_FRAME_COUNT * MARIO_SPRITE_FRAME_BYTES)
#define MARIO_LEVEL_WIDTH_TILES    128U
#define MARIO_LEVEL_HEIGHT_TILES   64U
#define MARIO_LEVEL_CELLS          \
    (MARIO_LEVEL_WIDTH_TILES * MARIO_LEVEL_HEIGHT_TILES)
#define MARIO_PALETTE_BYTES        32U

typedef struct {
    u8 *palette;
    u8 *tiles;
    u8 *hero_frames;
    u8 *enemy_frames;
    u8 *level_tiles;
    u8 *level_collision;
} mario_assets_t;

int mario_assets_load_from_sd(mario_assets_t *assets);
int mario_assets_upload_initial(mario_assets_t *assets, XAxiDma *dma);
int mario_assets_upload_hero_frame(
    mario_assets_t *assets,
    XAxiDma *dma,
    u8 frame
);
int mario_assets_upload_enemy_frame(
    mario_assets_t *assets,
    XAxiDma *dma,
    u8 sprite_slot,
    u8 frame
);
int mario_assets_upload_map_region(
    mario_assets_t *assets,
    XAxiDma *dma,
    u32 map_byte_offset
);

#endif
