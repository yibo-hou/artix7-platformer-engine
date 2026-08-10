#include "mario_assets.h"

#include "platform_config.h"
#include "sleep.h"
#include "sprite_engine_regs.h"
#include "xil_cache.h"
#include "xstatus.h"

#define ASSET_DMA_TIMEOUT 10000000U

static u8 palette_buffer[MARIO_PALETTE_BYTES]
    __attribute__((aligned(64), section(".game_assets")));
static u8 tile_buffer[MARIO_TILE_BYTES]
    __attribute__((aligned(64), section(".game_assets")));
static u8 hero_buffer[MARIO_SPRITE_SHEET_BYTES]
    __attribute__((aligned(64), section(".game_assets")));
static u8 enemy_buffer[MARIO_SPRITE_SHEET_BYTES]
    __attribute__((aligned(64), section(".game_assets")));
static u8 level_tile_buffer[MARIO_LEVEL_CELLS]
    __attribute__((aligned(64), section(".game_assets")));
static u8 level_collision_buffer[MARIO_LEVEL_CELLS]
    __attribute__((aligned(64), section(".game_assets")));

static int read_exact(const char *path, u8 *destination, u32 expected)
{
    FIL file;
    FRESULT result;
    UINT received;

    result = f_open(&file, path, FA_READ);
    if (result != FR_OK) {
        return -(int)result;
    }
    result = f_read(&file, destination, expected, &received);
    (void)f_close(&file);
    if (result != FR_OK || received != expected) {
        return -100;
    }
    return 0;
}

static int wait_status_clear(void)
{
    u32 timeout;
    u32 status;

    for (timeout = 0; timeout < ASSET_DMA_TIMEOUT; ++timeout) {
        status = SPR_REG32(MARIO_SPRITE_CTRL_BASEADDR, SPR_STATUS_OFFSET);
        if ((status & (SPR_STATUS_ASSET_DONE |
                       SPR_STATUS_ASSET_ERROR)) == 0U) {
            return 0;
        }
    }
    return -1;
}

static int asset_dma(
    XAxiDma *dma,
    u8 *source,
    u32 byte_count,
    u32 destination_kind,
    u32 destination_address)
{
    u32 timeout;
    u32 status;

    if ((((UINTPTR)source) & 31U) != 0U || byte_count == 0U) {
        return -1;
    }

    sprite_asset_set_destination(
        MARIO_SPRITE_CTRL_BASEADDR,
        destination_kind,
        destination_address
    );
    sprite_asset_clear_status(MARIO_SPRITE_CTRL_BASEADDR);
    if (wait_status_clear() != 0) {
        return -2;
    }

    /*
     * Target and clear commands cross to pixel_clk through the control FIFO.
     * Ten microseconds is far longer than the few cycles required.
     */
    usleep(10U);
    Xil_DCacheFlushRange((UINTPTR)source, byte_count);

    if (XAxiDma_SimpleTransfer(
            dma,
            (UINTPTR)source,
            byte_count,
            XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS) {
        return -3;
    }

    for (timeout = 0; timeout < ASSET_DMA_TIMEOUT; ++timeout) {
        if (!XAxiDma_Busy(dma, XAXIDMA_DMA_TO_DEVICE)) {
            break;
        }
    }
    if (timeout == ASSET_DMA_TIMEOUT) {
        return -4;
    }

    for (timeout = 0; timeout < ASSET_DMA_TIMEOUT; ++timeout) {
        status = SPR_REG32(MARIO_SPRITE_CTRL_BASEADDR, SPR_STATUS_OFFSET);
        if (status & SPR_STATUS_ASSET_ERROR) {
            return -5;
        }
        if (status & SPR_STATUS_ASSET_DONE) {
            return 0;
        }
    }
    return -6;
}

int mario_assets_load_from_sd(mario_assets_t *assets)
{
    int result;

    if (assets == NULL) {
        return -1;
    }

    assets->palette = palette_buffer;
    assets->tiles = tile_buffer;
    assets->hero_frames = hero_buffer;
    assets->enemy_frames = enemy_buffer;
    assets->level_tiles = level_tile_buffer;
    assets->level_collision = level_collision_buffer;

    result = read_exact("0:/GAME/PAL565.BIN", assets->palette,
                        MARIO_PALETTE_BYTES);
    if (result != 0) return result;
    result = read_exact("0:/GAME/TILES.BIN", assets->tiles,
                        MARIO_TILE_BYTES);
    if (result != 0) return result;
    result = read_exact("0:/GAME/HERO.BIN", assets->hero_frames,
                        MARIO_SPRITE_SHEET_BYTES);
    if (result != 0) return result;
    result = read_exact("0:/GAME/ENEMY.BIN", assets->enemy_frames,
                        MARIO_SPRITE_SHEET_BYTES);
    if (result != 0) return result;
    result = read_exact("0:/GAME/LEV01.MAP", assets->level_tiles,
                        MARIO_LEVEL_CELLS);
    if (result != 0) return result;
    return read_exact("0:/GAME/LEV01.COL", assets->level_collision,
                      MARIO_LEVEL_CELLS);
}

int mario_assets_upload_initial(mario_assets_t *assets, XAxiDma *dma)
{
    int result;

    result = asset_dma(dma, assets->palette, MARIO_PALETTE_BYTES,
                       SPR_ASSET_PALETTE, 0U);
    if (result != 0) return result;
    result = asset_dma(dma, assets->tiles, MARIO_TILE_BYTES,
                       SPR_ASSET_TILE_GRAPHICS, 0U);
    if (result != 0) return result;
    result = asset_dma(dma, assets->level_tiles, MARIO_LEVEL_CELLS,
                       SPR_ASSET_TILEMAP, 0U);
    if (result != 0) return result;
    return mario_assets_upload_hero_frame(assets, dma, 0U);
}

int mario_assets_upload_hero_frame(
    mario_assets_t *assets,
    XAxiDma *dma,
    u8 frame)
{
    if (frame >= MARIO_SPRITE_FRAME_COUNT) {
        return -1;
    }
    return asset_dma(
        dma,
        assets->hero_frames + (u32)frame * MARIO_SPRITE_FRAME_BYTES,
        MARIO_SPRITE_FRAME_BYTES,
        SPR_ASSET_SPRITE_GRAPHICS,
        0U
    );
}

int mario_assets_upload_enemy_frame(
    mario_assets_t *assets,
    XAxiDma *dma,
    u8 sprite_slot,
    u8 frame)
{
    if (sprite_slot == 0U || sprite_slot >= 16U ||
        frame >= MARIO_SPRITE_FRAME_COUNT) {
        return -1;
    }
    return asset_dma(
        dma,
        assets->enemy_frames + (u32)frame * MARIO_SPRITE_FRAME_BYTES,
        MARIO_SPRITE_FRAME_BYTES,
        SPR_ASSET_SPRITE_GRAPHICS,
        (u32)sprite_slot * MARIO_SPRITE_FRAME_BYTES
    );
}

int mario_assets_upload_map_region(
    mario_assets_t *assets,
    XAxiDma *dma,
    u32 map_byte_offset)
{
    u32 aligned_offset = map_byte_offset & ~31U;

    if (aligned_offset + 32U > MARIO_LEVEL_CELLS) {
        return -1;
    }
    return asset_dma(
        dma,
        assets->level_tiles + aligned_offset,
        32U,
        SPR_ASSET_TILEMAP,
        aligned_offset
    );
}
