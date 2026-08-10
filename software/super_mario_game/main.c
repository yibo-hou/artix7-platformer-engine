#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "xparameters.h"
#include "xuartlite_l.h"
#include "ff.h"
#include "sd_spi.h"
#include "sd_spi_diskio.h"

#define VDMA_BASE          0x44A00000U
#define MM2S_DMACR         (VDMA_BASE + 0x00U)
#define MM2S_DMASR         (VDMA_BASE + 0x04U)
#define VDMA_PARK_PTR      (VDMA_BASE + 0x28U)
#define MM2S_VSIZE         (VDMA_BASE + 0x50U)
#define MM2S_HSIZE         (VDMA_BASE + 0x54U)
#define MM2S_FRMDLY_STRIDE (VDMA_BASE + 0x58U)
#define MM2S_START_ADDR_1  (VDMA_BASE + 0x5CU)
#define MM2S_START_ADDR_2  (VDMA_BASE + 0x60U)
#define MM2S_START_ADDR_3  (VDMA_BASE + 0x64U)
#define S2MM_DMACR         (VDMA_BASE + 0x30U)
#define S2MM_DMASR         (VDMA_BASE + 0x34U)
#define S2MM_VSIZE         (VDMA_BASE + 0xA0U)
#define S2MM_HSIZE         (VDMA_BASE + 0xA4U)
#define S2MM_FRMDLY_STRIDE (VDMA_BASE + 0xA8U)
#define S2MM_START_ADDR_1  (VDMA_BASE + 0xACU)
#define S2MM_START_ADDR_2  (VDMA_BASE + 0xB0U)
#define S2MM_START_ADDR_3  (VDMA_BASE + 0xB4U)

#define RENDER_GPIO_BASE   0x41200000U
#define RENDER_GPIO_DATA   (RENDER_GPIO_BASE + 0x00U)
#define RENDER_GPIO_TRI    (RENDER_GPIO_BASE + 0x04U)

#define ASSET_GPIO_BASE    0x41210000U
#define ASSET_GPIO_DATA    (ASSET_GPIO_BASE + 0x00U)
#define ASSET_GPIO_TRI     (ASSET_GPIO_BASE + 0x04U)
#define ASSET_GPIO_DATA2   (ASSET_GPIO_BASE + 0x08U)
#define ASSET_GPIO_TRI2    (ASSET_GPIO_BASE + 0x0CU)

#define ASSET_TILEMAP      0U
#define ASSET_TILE_GFX     1U
#define ASSET_SPRITE_GFX   2U
#define ASSET_PALETTE      3U
#define ASSET_ACK_TIMEOUT  1000000U
#define HUD_COMMAND_MAGIC  0x155U
#define ENEMY_COMMAND_MAGIC 0x0BU

#define FRAME_WIDTH        1280U
#define FRAME_HEIGHT       720U
#define FRAME_STRIDE       (FRAME_WIDTH * 2U)
#define FRAME_BYTES        (FRAME_STRIDE * FRAME_HEIGHT)
#define FRAME0_ADDR        0x8C000000U
#define FRAME1_ADDR        0x8C200000U
#define FRAME2_ADDR        0x8C400000U
#define MENU_FRAME0_ADDR   0x8C600000U
#define MENU_FRAME1_ADDR   0x8C800000U
#define MENU_FRAME2_ADDR   0x8CA00000U

#define VDMA_DMACR_RUNSTOP 0x00000001U
#define VDMA_DMACR_CIRCULAR 0x00000002U
#define VDMA_DMACR_RESET   0x00000004U
#define VDMA_DMACR_GENLOCK 0x00000008U
#define VDMA_DMACR_GENLOCK_SRC 0x00000080U
#define VDMA_DMASR_HALTED  0x00000001U
#define VDMA_ERROR_MASK    0x00004FF0U
#define VDMA_STATUS_CLEAR_MASK 0x00007FF0U
#define VDMA_FRAME_IRQ     0x00001000U

#define RENDER_RUN         0x00000001U
#define SPRITE_ENABLE      0x00000002U
#define SPRITE_X_SHIFT     2U
#define SPRITE_Y_SHIFT     12U
#define CAMERA_X_SHIFT     21U
#define ACTIVE_SLOT_SHIFT  30U
#define FLIP_X_SHIFT       31U

#define KEY_LEFT           0x01U
#define KEY_RIGHT          0x02U
#define KEY_JUMP           0x04U
#define KEY_MASK           (KEY_LEFT | KEY_RIGHT | KEY_JUMP)

#define TILE_SIZE          16
#define LEVEL_WIDTH_TILES  128
#define LEVEL_HEIGHT_TILES 64
#define LEVEL_CELL_COUNT   (LEVEL_WIDTH_TILES * LEVEL_HEIGHT_TILES)
#define WORLD_WIDTH        (LEVEL_WIDTH_TILES * TILE_SIZE)
#define WORLD_HEIGHT       (LEVEL_HEIGHT_TILES * TILE_SIZE)
#define MAX_CAMERA_X       (WORLD_WIDTH - FRAME_WIDTH)
#define CAMERA_ANCHOR_X    400

#define HERO_WIDTH         32
#define HERO_HEIGHT        32
#define HERO_LEFT_INSET    4
#define HERO_RIGHT_INSET   4
#define HERO_TOP_INSET     2
#define HERO_SPAWN_X       48
#define HERO_SPAWN_Y       592
#define MOVE_PIXELS        2
#define POSITION_SHIFT     8
#define GRAVITY            192
#define JUMP_VELOCITY      (-3072)
#define DOUBLE_JUMP_VELOCITY (-2688)
#define FALL_VELOCITY_MAX  2048
#define INPUT_TIMEOUT_FRAMES 15U

#define GOAL_WORLD_X       (120 * TILE_SIZE)
#define GOAL_TRIGGER_X     (GOAL_WORLD_X - HERO_WIDTH)

#define HERO_FRAME_BYTES   1024U
#define HERO_FRAME_COUNT   16U
#define HERO_FRAME_IDLE    0U
#define HERO_FRAME_BLINK   1U
#define HERO_FRAME_WALK_0  2U
#define HERO_FRAME_WALK_COUNT 4U
#define HERO_FRAME_JUMP_RISE 9U
#define HERO_FRAME_JUMP_FALL 10U
#define HERO_FRAME_CROUCH  12U
#define HERO_FRAME_HURT    13U
#define HERO_FRAME_VICTORY 14U
#define WALK_FRAME_TICKS   6U
#define BLINK_PERIOD_FRAMES 180U
#define BLINK_HOLD_FRAMES  6U

#define COLLISION_EMPTY    0U
#define COLLISION_SOLID    1U
#define COLLISION_HAZARD   2U
#define COLLISION_GOAL     3U
#define COLLISION_REWARD   4U
#define COLLISION_COIN     5U
#define COLLISION_HEALTH   6U
#define COLLISION_STAR     7U

#define TILE_SKY           3U
#define LEVEL_COIN_TOTAL   34U
#define PLAYER_HEALTH_MAX  3U
#define GAME_OVER_HOLD_FRAMES 120U
#define GAME_OVER_ANIMATION_TICKS 8U
#define INVINCIBILITY_FRAMES 300U
#define ENEMY_MOVE_DIVIDER 3U
#define ENEMY_COUNT        4U
#define ENEMY_WIDTH        32
#define ENEMY_HEIGHT       32
#define LEVEL_COUNT        3U

#ifndef XPAR_AXI_QUAD_SPI_0_BASEADDR
#define XPAR_AXI_QUAD_SPI_0_BASEADDR 0x44A10000U
#endif

typedef struct {
    const char *path;
    u32 size;
    u32 crc32;
} sd_expected_file_t;

typedef struct {
    int x;
    int y;
    int patrol_min;
    int patrol_max;
    int direction;
    u32 sprite_slot;
    u32 source_frame;
} enemy_state_t;

typedef struct {
    const char *name;
    const char *map_path;
    const char *collision_path;
    int spawn_x;
    int spawn_y;
    int goal_trigger_x;
    enemy_state_t enemies[ENEMY_COUNT];
} level_config_t;

static const level_config_t level_configs[LEVEL_COUNT] = {
    {
        "COPPER HILLS", "0:/GAME/LEV01.MAP", "0:/GAME/LEV01.COL",
        3 * TILE_SIZE, 37 * TILE_SIZE, 120 * TILE_SIZE - HERO_WIDTH,
        {
            {24 * TILE_SIZE, 37 * TILE_SIZE, 22 * TILE_SIZE,
             26 * TILE_SIZE, 1, 2U, 0U},
            {40 * TILE_SIZE, 37 * TILE_SIZE, 38 * TILE_SIZE,
             42 * TILE_SIZE, -1, 3U, 4U},
            {59 * TILE_SIZE, 25 * TILE_SIZE, 54 * TILE_SIZE,
             64 * TILE_SIZE, 1, 4U, 8U},
            {81 * TILE_SIZE, 37 * TILE_SIZE, 78 * TILE_SIZE,
             90 * TILE_SIZE, -1, 5U, 12U},
        }
    },
    {
        "SKY BRIDGES", "0:/GAME/LEV02.MAP", "0:/GAME/LEV02.COL",
        3 * TILE_SIZE, 37 * TILE_SIZE, 124 * TILE_SIZE - HERO_WIDTH,
        {
            {10 * TILE_SIZE, 33 * TILE_SIZE, 7 * TILE_SIZE,
             12 * TILE_SIZE, 1, 2U, 0U},
            {39 * TILE_SIZE, 37 * TILE_SIZE, 36 * TILE_SIZE,
             43 * TILE_SIZE, -1, 3U, 4U},
            {67 * TILE_SIZE, 19 * TILE_SIZE, 64 * TILE_SIZE,
             72 * TILE_SIZE, 1, 4U, 8U},
            {95 * TILE_SIZE, 26 * TILE_SIZE, 92 * TILE_SIZE,
             98 * TILE_SIZE, -1, 5U, 12U},
        }
    },
    {
        "STARFALL RUN", "0:/GAME/LEV03.MAP", "0:/GAME/LEV03.COL",
        3 * TILE_SIZE, 37 * TILE_SIZE, 124 * TILE_SIZE - HERO_WIDTH,
        {
            {11 * TILE_SIZE, 29 * TILE_SIZE, 8 * TILE_SIZE,
             14 * TILE_SIZE, 1, 2U, 0U},
            {35 * TILE_SIZE, 31 * TILE_SIZE, 33 * TILE_SIZE,
             40 * TILE_SIZE, -1, 3U, 4U},
            {60 * TILE_SIZE, 22 * TILE_SIZE, 57 * TILE_SIZE,
             64 * TILE_SIZE, 1, 4U, 8U},
            {106 * TILE_SIZE, 27 * TILE_SIZE, 103 * TILE_SIZE,
             109 * TILE_SIZE, -1, 5U, 12U},
        }
    },
};

static const sd_expected_file_t sd_expected_files[] = {
    {"0:/GAME/ENEMY.BIN",   16384U, 0x0933C9B4U},
    {"0:/GAME/HERO.BIN",    16384U, 0xCA451CADU},
    {"0:/GAME/LEV01.COL",    8192U, 0xD826F0B8U},
    {"0:/GAME/LEV01.JSN",    2647U, 0xB1313EE4U},
    {"0:/GAME/LEV01.MAP",    8192U, 0xA9BC8453U},
    {"0:/GAME/LEV02.COL",    8192U, 0x5B750EB7U},
    {"0:/GAME/LEV02.JSN",    2584U, 0x00C2CF3AU},
    {"0:/GAME/LEV02.MAP",    8192U, 0xABB374E8U},
    {"0:/GAME/LEV03.COL",    8192U, 0x1E35C3B0U},
    {"0:/GAME/LEV03.JSN",    2581U, 0x1867DBC4U},
    {"0:/GAME/LEV03.MAP",    8192U, 0x6F16F06DU},
    {"0:/GAME/MANIFEST.JSN", 1591U, 0xCBC2551EU},
    {"0:/GAME/PAL565.BIN",     32U, 0x0086F699U},
    {"0:/GAME/TILES.BIN",   16384U, 0xA69E16E8U},
};

static sd_spi_t sd_card;
static FATFS sd_fatfs;
static u8 sd_read_buffer[512];
static u8 level_collision[LEVEL_CELL_COUNT];
static u8 hero_frame_cache[HERO_FRAME_COUNT][HERO_FRAME_BYTES];

static u32 crc32_update(u32 crc, const u8 *data, UINT length)
{
    UINT byte_index;

    for (byte_index = 0U; byte_index < length; ++byte_index) {
        u32 bit;
        crc ^= data[byte_index];
        for (bit = 0U; bit < 8U; ++bit) {
            crc = (crc >> 1) ^
                  ((crc & 1U) ? 0xEDB88320U : 0U);
        }
    }
    return crc;
}

static int verify_sd_game_files(void)
{
    FRESULT fat_result;
    sd_spi_result_t sd_result;
    u32 file_index;

    xil_printf("SD: initializing SPI card at 390.625 kHz...\r\n");
    sd_result = sd_spi_init(
        &sd_card, (UINTPTR)XPAR_AXI_QUAD_SPI_0_BASEADDR
    );
    if (sd_result != SD_SPI_OK) {
        u32 byte_index;
        xil_printf("ERROR: SD initialization failed %d\r\n", sd_result);
        xil_printf("SD last response bytes:");
        for (byte_index = 0U; byte_index < 22U; ++byte_index) {
            xil_printf(" %02x", (unsigned int)sd_card.scratch_rx[byte_index]);
        }
        xil_printf("\r\n");
        return -1;
    }
    xil_printf("SD: card initialized, type=%u\r\n",
               (unsigned int)sd_card.card_type);

    sd_spi_diskio_bind(&sd_card);
    fat_result = f_mount(&sd_fatfs, "0:", 1U);
    if (fat_result != FR_OK) {
        xil_printf("ERROR: FAT mount failed %u\r\n",
                   (unsigned int)fat_result);
        return -2;
    }

    for (file_index = 0U;
         file_index < sizeof(sd_expected_files) / sizeof(sd_expected_files[0]);
         ++file_index) {
        const sd_expected_file_t *expected = &sd_expected_files[file_index];
        FIL file;
        u32 crc = 0xFFFFFFFFU;
        u32 total = 0U;

        fat_result = f_open(&file, expected->path, FA_READ);
        if (fat_result != FR_OK) {
            xil_printf("ERROR: cannot open %s, FatFs=%u\r\n",
                       expected->path, (unsigned int)fat_result);
            return -3;
        }

        for (;;) {
            UINT bytes_read = 0U;
            fat_result = f_read(
                &file, sd_read_buffer, sizeof(sd_read_buffer), &bytes_read
            );
            if (fat_result != FR_OK) {
                (void)f_close(&file);
                xil_printf("ERROR: read %s failed, FatFs=%u\r\n",
                           expected->path, (unsigned int)fat_result);
                return -4;
            }
            if (bytes_read == 0U) {
                break;
            }
            crc = crc32_update(crc, sd_read_buffer, bytes_read);
            total += bytes_read;
        }
        (void)f_close(&file);
        crc ^= 0xFFFFFFFFU;

        if (total != expected->size || crc != expected->crc32) {
            xil_printf("ERROR: %s size=%u crc=0x%08x expected=%u/0x%08x\r\n",
                       expected->path,
                       (unsigned int)total,
                       (unsigned int)crc,
                       (unsigned int)expected->size,
                       (unsigned int)expected->crc32);
            return -5;
        }
        xil_printf("SD OK: %s size=%u crc=0x%08x\r\n",
                   expected->path,
                   (unsigned int)total,
                   (unsigned int)crc);
    }

    xil_printf("SD GAME asset verification complete\r\n");
    return 0;
}

static void asset_loader_init(void)
{
    /* Channel 1 is the command output; channel 2 is the acknowledge input. */
    Xil_Out32(ASSET_GPIO_TRI, 0x00000000U);
    Xil_Out32(ASSET_GPIO_TRI2, 0x00000001U);
    Xil_Out32(ASSET_GPIO_DATA, 0x00000000U);
}

static int asset_write(u32 kind, u32 address, u32 value)
{
    u32 acknowledge = Xil_In32(ASSET_GPIO_DATA2) & 1U;
    u32 sequence = acknowledge ^ 1U;
    u32 command;
    u32 timeout;

    if (kind == ASSET_PALETTE) {
        command = (sequence << 31) |
                  (ASSET_PALETTE << 29) |
                  ((address & 0x0FU) << 25) |
                  ((value & 0xFFFFU) << 9);
    } else {
        command = (sequence << 31) |
                  ((kind & 0x03U) << 29) |
                  ((address & 0x3FFFU) << 15) |
                  (value & 0xFFU);
    }

    Xil_Out32(ASSET_GPIO_DATA, command);
    for (timeout = 0U; timeout < ASSET_ACK_TIMEOUT; ++timeout) {
        if ((Xil_In32(ASSET_GPIO_DATA2) & 1U) == sequence) {
            return 0;
        }
    }

    xil_printf("ERROR: asset acknowledge timeout kind=%u address=%u\r\n",
               (unsigned int)kind, (unsigned int)address);
    return -1;
}

static int hud_update(
    u32 coin_count, int goal_reached, u32 health, int power_active)
{
    u32 acknowledge = Xil_In32(ASSET_GPIO_DATA2) & 1U;
    u32 sequence = acknowledge ^ 1U;
    u32 command = (sequence << 31) |
                  (ASSET_PALETTE << 29) |
                  (1U << 19) |
                  ((u32)(power_active != 0) << 18) |
                  ((health & 0x03U) << 16) |
                  ((u32)(goal_reached != 0) << 15) |
                  ((coin_count & 0x3FU) << 9) |
                  HUD_COMMAND_MAGIC;
    u32 timeout;

    Xil_Out32(ASSET_GPIO_DATA, command);
    for (timeout = 0U; timeout < ASSET_ACK_TIMEOUT; ++timeout) {
        if ((Xil_In32(ASSET_GPIO_DATA2) & 1U) == sequence) {
            return 0;
        }
    }

    xil_printf("ERROR: HUD acknowledge timeout coins=%u goal=%u hp=%u "
               "power=%u\r\n",
               (unsigned int)coin_count,
               (unsigned int)(goal_reached != 0),
               (unsigned int)health,
               (unsigned int)(power_active != 0));
    return -1;
}

static int enemy_attr_update(
    u32 slot, int world_x, int screen_y, int enabled, int flip_x)
{
    u32 acknowledge = Xil_In32(ASSET_GPIO_DATA2) & 1U;
    u32 sequence = acknowledge ^ 1U;
    u32 command;
    u32 timeout;

    if (world_x < 0)
        world_x = 0;
    if (screen_y < 0)
        screen_y = 0;
    /* Full-pixel enemy command: [28:18] world X, [17:8] screen Y,
     * [7:6] slot-2, [5] enable, [4] flip and [3:0] magic.  Hardware applies
     * the frame's camera snapshot to every enemy together, preventing a
     * one-frame camera/attribute epoch mismatch. */
    command = (sequence << 31) |
              (ASSET_PALETTE << 29) |
              (((u32)world_x & 0x7FFU) << 18) |
              (((u32)screen_y & 0x3FFU) << 8) |
              (((slot - 2U) & 0x03U) << 6) |
              ((u32)(enabled != 0) << 5) |
              ((u32)(flip_x != 0) << 4) |
              (ENEMY_COMMAND_MAGIC & 0x0FU);

    Xil_Out32(ASSET_GPIO_DATA, command);
    for (timeout = 0U; timeout < ASSET_ACK_TIMEOUT; ++timeout) {
        if ((Xil_In32(ASSET_GPIO_DATA2) & 1U) == sequence)
            return 0;
    }

    xil_printf("ERROR: enemy attribute acknowledge timeout slot=%u\r\n",
               (unsigned int)slot);
    return -1;
}

static int load_indexed_asset(const char *path, u32 expected_size, u32 kind)
{
    FIL file;
    FRESULT fat_result;
    u32 total = 0U;

    fat_result = f_open(&file, path, FA_READ);
    if (fat_result != FR_OK) {
        xil_printf("ERROR: cannot open asset %s, FatFs=%u\r\n",
                   path, (unsigned int)fat_result);
        return -1;
    }

    while (total < expected_size) {
        UINT bytes_read = 0U;
        UINT byte_index;

        fat_result = f_read(
            &file, sd_read_buffer, sizeof(sd_read_buffer), &bytes_read
        );
        if (fat_result != FR_OK || bytes_read == 0U ||
            total + bytes_read > expected_size) {
            (void)f_close(&file);
            xil_printf("ERROR: invalid asset data %s at byte %u, FatFs=%u\r\n",
                       path, (unsigned int)total,
                       (unsigned int)fat_result);
            return -2;
        }

        for (byte_index = 0U; byte_index < bytes_read; ++byte_index) {
            if (asset_write(kind, total + byte_index,
                            sd_read_buffer[byte_index]) != 0) {
                (void)f_close(&file);
                return -3;
            }
        }
        total += bytes_read;
    }

    (void)f_close(&file);
    xil_printf("Asset loaded: %s (%u bytes)\r\n",
               path, (unsigned int)total);
    return 0;
}

static int load_palette(void)
{
    FIL file;
    FRESULT fat_result;
    UINT bytes_read = 0U;
    u32 palette_index;

    fat_result = f_open(&file, "0:/GAME/PAL565.BIN", FA_READ);
    if (fat_result != FR_OK) {
        xil_printf("ERROR: cannot open palette, FatFs=%u\r\n",
                   (unsigned int)fat_result);
        return -1;
    }
    fat_result = f_read(&file, sd_read_buffer, 32U, &bytes_read);
    (void)f_close(&file);
    if (fat_result != FR_OK || bytes_read != 32U) {
        xil_printf("ERROR: palette read failed, FatFs=%u bytes=%u\r\n",
                   (unsigned int)fat_result, (unsigned int)bytes_read);
        return -2;
    }

    for (palette_index = 0U; palette_index < 16U; ++palette_index) {
        u32 rgb565 = (u32)sd_read_buffer[palette_index * 2U] |
                     ((u32)sd_read_buffer[palette_index * 2U + 1U] << 8);
        if (asset_write(ASSET_PALETTE, palette_index, rgb565) != 0) {
            return -3;
        }
    }

    xil_printf("Asset loaded: 0:/GAME/PAL565.BIN (16 colors)\r\n");
    return 0;
}

static int cache_hero_frames(void)
{
    FIL file;
    FRESULT fat_result;
    UINT bytes_read = 0U;

    fat_result = f_open(&file, "0:/GAME/HERO.BIN", FA_READ);
    if (fat_result != FR_OK) {
        xil_printf("ERROR: cannot open HERO.BIN for cache, FatFs=%u\r\n",
                   (unsigned int)fat_result);
        return -1;
    }
    fat_result = f_read(
        &file, hero_frame_cache, sizeof(hero_frame_cache), &bytes_read
    );
    (void)f_close(&file);
    if (fat_result != FR_OK || bytes_read != sizeof(hero_frame_cache)) {
        xil_printf("ERROR: HERO cache read failed, FatFs=%u bytes=%u\r\n",
                   (unsigned int)fat_result, (unsigned int)bytes_read);
        return -2;
    }

    xil_printf("Hero animation cached in BRAM: %u frames\r\n",
               (unsigned int)HERO_FRAME_COUNT);
    return 0;
}

static int upload_cached_hero_frame(u32 frame_index, u32 slot)
{
    u32 byte_index;

    if (frame_index >= HERO_FRAME_COUNT || slot >= 2U) {
        return -1;
    }
    for (byte_index = 0U; byte_index < HERO_FRAME_BYTES; ++byte_index) {
        if (asset_write(
                ASSET_SPRITE_GFX,
                slot * HERO_FRAME_BYTES + byte_index,
                hero_frame_cache[frame_index][byte_index]) != 0) {
            return -2;
        }
    }
    return 0;
}

static int load_enemy_frame(u32 frame_index, u32 slot)
{
    FIL file;
    FRESULT fat_result;
    UINT bytes_read = 0U;
    u32 byte_index;
    u32 half;

    fat_result = f_open(&file, "0:/GAME/ENEMY.BIN", FA_READ);
    if (fat_result != FR_OK)
        return -1;
    fat_result = f_lseek(&file, frame_index * HERO_FRAME_BYTES);
    if (fat_result != FR_OK) {
        (void)f_close(&file);
        return -2;
    }

    for (half = 0U; half < 2U; ++half) {
        bytes_read = 0U;
        fat_result = f_read(
            &file, sd_read_buffer, sizeof(sd_read_buffer), &bytes_read
        );
        if (fat_result != FR_OK || bytes_read != sizeof(sd_read_buffer)) {
            (void)f_close(&file);
            return -3;
        }
        for (byte_index = 0U;
             byte_index < sizeof(sd_read_buffer); ++byte_index) {
            if (asset_write(
                    ASSET_SPRITE_GFX,
                    slot * HERO_FRAME_BYTES + half * 512U + byte_index,
                    sd_read_buffer[byte_index]) != 0) {
                (void)f_close(&file);
                return -4;
            }
        }
    }
    (void)f_close(&file);
    return 0;
}

static int load_game_assets_to_renderer(const level_config_t *level)
{
    xil_printf("Loading SD assets into Sprite Engine...\r\n");
    asset_loader_init();

    if (load_palette() != 0)
        return -1;
    if (load_indexed_asset(
            "0:/GAME/TILES.BIN", 16384U, ASSET_TILE_GFX) != 0)
        return -2;
    if (load_indexed_asset(
            level->map_path, 8192U, ASSET_TILEMAP) != 0)
        return -3;
    if (cache_hero_frames() != 0)
        return -4;
    /* The two hardware banks initially hold idle and blink. */
    if (upload_cached_hero_frame(HERO_FRAME_IDLE, 0U) != 0 ||
        upload_cached_hero_frame(HERO_FRAME_BLINK, 1U) != 0)
        return -5;
    if (load_enemy_frame(0U, 2U) != 0 ||
        load_enemy_frame(4U, 3U) != 0 ||
        load_enemy_frame(8U, 4U) != 0 ||
        load_enemy_frame(12U, 5U) != 0)
        return -6;

    xil_printf("Sprite Engine asset load complete\r\n");
    return 0;
}

static int load_level_collision(const level_config_t *level)
{
    FIL file;
    FRESULT fat_result;
    UINT bytes_read = 0U;

    fat_result = f_open(&file, level->collision_path, FA_READ);
    if (fat_result != FR_OK) {
        xil_printf("ERROR: cannot open collision map, FatFs=%u\r\n",
                   (unsigned int)fat_result);
        return -1;
    }

    fat_result = f_read(
        &file, level_collision, sizeof(level_collision), &bytes_read
    );
    (void)f_close(&file);
    if (fat_result != FR_OK || bytes_read != sizeof(level_collision)) {
        xil_printf("ERROR: collision map read failed, FatFs=%u bytes=%u\r\n",
                   (unsigned int)fat_result, (unsigned int)bytes_read);
        return -2;
    }

    xil_printf("Collision map loaded: %s (%u cells)\r\n",
               level->name, (unsigned int)bytes_read);
    return 0;
}

static u8 collision_at(int pixel_x, int pixel_y)
{
    u32 tile_x;
    u32 tile_y;

    if (pixel_y < 0)
        return COLLISION_EMPTY;
    if (pixel_x < 0 || pixel_x >= WORLD_WIDTH)
        return COLLISION_SOLID;
    if (pixel_y >= WORLD_HEIGHT)
        return COLLISION_HAZARD;

    tile_x = (u32)pixel_x >> 4;
    tile_y = (u32)pixel_y >> 4;
    return level_collision[tile_y * LEVEL_WIDTH_TILES + tile_x];
}

static int collision_is_solid(u8 value)
{
    return value == COLLISION_SOLID || value == COLLISION_REWARD;
}

static u32 collect_coins(int hero_x, int hero_y, u32 coin_count)
{
    int tile_x0 = (hero_x + HERO_LEFT_INSET) >> 4;
    int tile_x1 = (hero_x + HERO_WIDTH - HERO_RIGHT_INSET - 1) >> 4;
    int tile_y0 = (hero_y + HERO_TOP_INSET) >> 4;
    int tile_y1 = (hero_y + HERO_HEIGHT - 1) >> 4;
    int tile_y;

    for (tile_y = tile_y0; tile_y <= tile_y1; ++tile_y) {
        int tile_x;
        for (tile_x = tile_x0; tile_x <= tile_x1; ++tile_x) {
            u32 offset;

            if (tile_x < 0 || tile_x >= LEVEL_WIDTH_TILES ||
                tile_y < 0 || tile_y >= LEVEL_HEIGHT_TILES) {
                continue;
            }
            offset = (u32)tile_y * LEVEL_WIDTH_TILES + (u32)tile_x;
            if (level_collision[offset] != COLLISION_COIN)
                continue;

            if (asset_write(ASSET_TILEMAP, offset, TILE_SKY) != 0) {
                xil_printf("ERROR: failed to remove coin at tile %d,%d\r\n",
                           tile_x, tile_y);
                continue;
            }
            level_collision[offset] = COLLISION_EMPTY;
            ++coin_count;
            xil_printf("Coin collected: %u at tile %d,%d\r\n",
                       (unsigned int)coin_count, tile_x, tile_y);
        }
    }
    return coin_count;
}

static int collect_items(
    int hero_x,
    int hero_y,
    u32 *health,
    u32 *invincibility_ticks)
{
    int tile_x0 = (hero_x + HERO_LEFT_INSET) >> 4;
    int tile_x1 = (hero_x + HERO_WIDTH - HERO_RIGHT_INSET - 1) >> 4;
    int tile_y0 = (hero_y + HERO_TOP_INSET) >> 4;
    int tile_y1 = (hero_y + HERO_HEIGHT - 1) >> 4;
    int changed = 0;
    int tile_y;

    for (tile_y = tile_y0; tile_y <= tile_y1; ++tile_y) {
        int tile_x;
        for (tile_x = tile_x0; tile_x <= tile_x1; ++tile_x) {
            u32 offset;
            u8 item;

            if (tile_x < 0 || tile_x >= LEVEL_WIDTH_TILES ||
                tile_y < 0 || tile_y >= LEVEL_HEIGHT_TILES)
                continue;
            offset = (u32)tile_y * LEVEL_WIDTH_TILES + (u32)tile_x;
            item = level_collision[offset];
            if (item != COLLISION_HEALTH && item != COLLISION_STAR)
                continue;

            // Do not waste a health pickup while the health bar is full.
            // It remains in the map so the player can return after damage.
            if (item == COLLISION_HEALTH && *health >= PLAYER_HEALTH_MAX)
                continue;

            if (asset_write(ASSET_TILEMAP, offset, TILE_SKY) != 0) {
                xil_printf("ERROR: failed to remove item at tile %d,%d\r\n",
                           tile_x, tile_y);
                continue;
            }
            level_collision[offset] = COLLISION_EMPTY;
            changed = 1;
            if (item == COLLISION_HEALTH) {
                ++*health;
                xil_printf("Health item: hp=%u at tile %d,%d\r\n",
                           (unsigned int)*health, tile_x, tile_y);
            } else {
                *invincibility_ticks = INVINCIBILITY_FRAMES;
                xil_printf("Star item: invincible for %u frames\r\n",
                           (unsigned int)INVINCIBILITY_FRAMES);
            }
        }
    }
    return changed;
}

static int hero_touches_collision(int hero_x, int hero_y, u8 target)
{
    int tile_x0 = (hero_x + HERO_LEFT_INSET) >> 4;
    int tile_x1 = (hero_x + HERO_WIDTH - HERO_RIGHT_INSET - 1) >> 4;
    int tile_y0 = (hero_y + HERO_TOP_INSET) >> 4;
    int tile_y1 = (hero_y + HERO_HEIGHT - 1) >> 4;
    int tile_y;

    for (tile_y = tile_y0; tile_y <= tile_y1; ++tile_y) {
        int tile_x;
        for (tile_x = tile_x0; tile_x <= tile_x1; ++tile_x) {
            if (tile_x >= 0 && tile_x < LEVEL_WIDTH_TILES &&
                tile_y >= 0 && tile_y < LEVEL_HEIGHT_TILES &&
                level_collision[
                    tile_y * LEVEL_WIDTH_TILES + tile_x] == target) {
                return 1;
            }
        }
    }
    return 0;
}

static void move_hero_horizontal(int *hero_x, int hero_y, int delta_x)
{
    int next_x = *hero_x + delta_x;
    int sample_top = hero_y + HERO_TOP_INSET + 2;
    int sample_bottom = hero_y + HERO_HEIGHT - 2;

    if (delta_x > 0) {
        int right = next_x + HERO_WIDTH - HERO_RIGHT_INSET - 1;
        if (collision_is_solid(collision_at(right, sample_top)) ||
            collision_is_solid(collision_at(right, sample_bottom))) {
            next_x = ((right >> 4) << 4) -
                     (HERO_WIDTH - HERO_RIGHT_INSET);
        }
    } else if (delta_x < 0) {
        int left = next_x + HERO_LEFT_INSET;
        if (collision_is_solid(collision_at(left, sample_top)) ||
            collision_is_solid(collision_at(left, sample_bottom))) {
            next_x = (((left >> 4) + 1) << 4) - HERO_LEFT_INSET;
        }
    }

    if (next_x < 0)
        next_x = 0;
    if (next_x > WORLD_WIDTH - HERO_WIDTH)
        next_x = WORLD_WIDTH - HERO_WIDTH;
    *hero_x = next_x;
}

static void move_hero_vertical(
    int hero_x,
    int *hero_y,
    int *hero_y_fp,
    int *velocity_y,
    int *grounded)
{
    int sample_left = hero_x + HERO_LEFT_INSET + 2;
    int sample_right = hero_x + HERO_WIDTH - HERO_RIGHT_INSET - 2;
    int next_y;

    *velocity_y += GRAVITY;
    if (*velocity_y > FALL_VELOCITY_MAX)
        *velocity_y = FALL_VELOCITY_MAX;

    *hero_y_fp += *velocity_y;
    next_y = *hero_y_fp >> POSITION_SHIFT;
    *grounded = 0;

    if (*velocity_y >= 0) {
        int bottom = next_y + HERO_HEIGHT - 1;
        if (collision_is_solid(collision_at(sample_left, bottom)) ||
            collision_is_solid(collision_at(sample_right, bottom))) {
            next_y = ((bottom >> 4) << 4) - HERO_HEIGHT;
            *hero_y_fp = next_y << POSITION_SHIFT;
            *velocity_y = 0;
            *grounded = 1;
        } else if (
            collision_is_solid(collision_at(sample_left, bottom + 1)) ||
            collision_is_solid(collision_at(sample_right, bottom + 1))) {
            *velocity_y = 0;
            *grounded = 1;
        }
    } else {
        int top = next_y + HERO_TOP_INSET;
        if (collision_is_solid(collision_at(sample_left, top)) ||
            collision_is_solid(collision_at(sample_right, top))) {
            next_y = (((top >> 4) + 1) << 4) - HERO_TOP_INSET;
            *hero_y_fp = next_y << POSITION_SHIFT;
            *velocity_y = 0;
        }
    }

    *hero_y = next_y;
}

static int camera_for_hero(int hero_x)
{
    int camera_x = hero_x - CAMERA_ANCHOR_X;

    if (camera_x < 0)
        camera_x = 0;
    if (camera_x > (int)MAX_CAMERA_X)
        camera_x = (int)MAX_CAMERA_X;
    return camera_x & ~1;
}

static int hero_hits_enemy(int hero_x, int hero_y, const enemy_state_t *enemy)
{
    int hero_left = hero_x + HERO_LEFT_INSET;
    int hero_right = hero_x + HERO_WIDTH - HERO_RIGHT_INSET;
    int hero_top = hero_y + HERO_TOP_INSET;
    int hero_bottom = hero_y + HERO_HEIGHT;
    int enemy_left = enemy->x + 3;
    int enemy_right = enemy->x + ENEMY_WIDTH - 3;
    int enemy_top = enemy->y + 3;
    int enemy_bottom = enemy->y + ENEMY_HEIGHT;

    return hero_left < enemy_right && hero_right > enemy_left &&
           hero_top < enemy_bottom && hero_bottom > enemy_top;
}

static void update_enemies(enemy_state_t *enemies)
{
    u32 index;

    for (index = 0U; index < ENEMY_COUNT; ++index) {
        enemy_state_t *enemy = &enemies[index];
        enemy->x += enemy->direction;
        if (enemy->x <= enemy->patrol_min) {
            enemy->x = enemy->patrol_min;
            enemy->direction = 1;
        } else if (enemy->x >= enemy->patrol_max) {
            enemy->x = enemy->patrol_max;
            enemy->direction = -1;
        }
    }
}

static int publish_enemy_attributes(
    const enemy_state_t *enemies, int camera_x)
{
    u32 index;

    for (index = 0U; index < ENEMY_COUNT; ++index) {
        if (enemy_attr_update(
                enemies[index].sprite_slot,
                enemies[index].x,
                enemies[index].y,
                1,
                0) != 0)
            return -1;
    }
    (void)camera_x;
    return 0;
}

static u8 receive_keyboard_state(u8 previous, int *received)
{
    *received = 0;
    while (!XUartLite_IsReceiveEmpty(XPAR_AXI_UARTLITE_0_BASEADDR)) {
        previous = (u8)XUartLite_ReadReg(
            XPAR_AXI_UARTLITE_0_BASEADDR,
            XUL_RX_FIFO_OFFSET
        );
        *received = 1;
    }
    return previous & KEY_MASK;
}

static u32 make_render_control(
    int sprite_x,
    int sprite_y,
    int camera_x,
    u32 active_slot,
    int flip_x,
    int hero_visible)
{
    return RENDER_RUN | (hero_visible ? SPRITE_ENABLE : 0U) |
           ((u32)(sprite_x >> 1) << SPRITE_X_SHIFT) |
           ((u32)(sprite_y >> 1) << SPRITE_Y_SHIFT) |
           ((u32)(camera_x >> 1) << CAMERA_X_SHIFT) |
           ((active_slot & 1U) << ACTIVE_SLOT_SHIFT) |
           ((u32)(flip_x != 0) << FLIP_X_SHIFT);
}

#define MENU_GLYPH(a, b, c, d, e, f, g) \
    (((u64)(a) << 30) | ((u64)(b) << 25) | ((u64)(c) << 20) | \
     ((u64)(d) << 15) | ((u64)(e) << 10) | ((u64)(f) << 5) | (u64)(g))

static u64 menu_glyph(char character)
{
    switch (character) {
    case 'A': return MENU_GLYPH(14,17,17,31,17,17,17);
    case 'B': return MENU_GLYPH(30,17,17,30,17,17,30);
    case 'C': return MENU_GLYPH(15,16,16,16,16,16,15);
    case 'D': return MENU_GLYPH(30,17,17,17,17,17,30);
    case 'E': return MENU_GLYPH(31,16,16,30,16,16,31);
    case 'F': return MENU_GLYPH(31,16,16,30,16,16,16);
    case 'G': return MENU_GLYPH(15,16,16,23,17,17,15);
    case 'H': return MENU_GLYPH(17,17,17,31,17,17,17);
    case 'I': return MENU_GLYPH(31,4,4,4,4,4,31);
    case 'K': return MENU_GLYPH(17,18,20,24,20,18,17);
    case 'L': return MENU_GLYPH(16,16,16,16,16,16,31);
    case 'N': return MENU_GLYPH(17,25,21,19,17,17,17);
    case 'O': return MENU_GLYPH(14,17,17,17,17,17,14);
    case 'P': return MENU_GLYPH(30,17,17,30,16,16,16);
    case 'R': return MENU_GLYPH(30,17,17,30,20,18,17);
    case 'S': return MENU_GLYPH(15,16,16,14,1,1,30);
    case 'T': return MENU_GLYPH(31,4,4,4,4,4,4);
    case 'U': return MENU_GLYPH(17,17,17,17,17,17,14);
    case 'V': return MENU_GLYPH(17,17,17,17,17,10,4);
    case 'Y': return MENU_GLYPH(17,17,10,4,4,4,4);
    case '1': return MENU_GLYPH(4,12,4,4,4,4,14);
    case '2': return MENU_GLYPH(14,17,1,2,4,8,31);
    case '3': return MENU_GLYPH(30,1,1,14,1,1,30);
    default: return 0U;
    }
}

static void menu_fill_rect(
    volatile u16 *pixels, int x0, int y0, int width, int height, u16 color)
{
    int y;
    for (y = y0; y < y0 + height; ++y) {
        int x;
        for (x = x0; x < x0 + width; ++x)
            pixels[y * FRAME_WIDTH + x] = color;
    }
}

static void menu_draw_char(
    volatile u16 *pixels, int x0, int y0, char character,
    int scale, u16 color)
{
    u64 glyph = menu_glyph(character);
    int row;

    for (row = 0; row < 7; ++row) {
        u32 bits = (u32)((glyph >> ((6 - row) * 5)) & 0x1FU);
        int column;
        for (column = 0; column < 5; ++column) {
            if ((bits & (1U << (4 - column))) != 0U) {
                menu_fill_rect(
                    pixels, x0 + column * scale, y0 + row * scale,
                    scale, scale, color);
            }
        }
    }
}

static void menu_draw_text(
    volatile u16 *pixels, int x, int y, const char *text,
    int scale, u16 color)
{
    while (*text != '\0') {
        menu_draw_char(pixels, x, y, *text, scale, color);
        x += scale * 6;
        ++text;
    }
}

static void draw_level_select_frame(
    UINTPTR address, u32 selected_level, int loading)
{
    static const int card_x[LEVEL_COUNT] = {48, 464, 880};
    static const u16 card_color[LEVEL_COUNT] = {
        0xCA42U, 0x0418U, 0x780FU
    };
    volatile u16 *pixels = (volatile u16 *)address;
    u32 card;
    int y;

    menu_fill_rect(pixels, 0, 0, FRAME_WIDTH, FRAME_HEIGHT, 0x84FFU);
    for (y = 0; y < FRAME_HEIGHT; y += 32) {
        if (((u32)y & 64U) != 0U)
            menu_fill_rect(pixels, 0, y, FRAME_WIDTH, 16, 0x7CBEU);
    }

    menu_draw_text(pixels, 424, 72, "SELECT LEVEL", 6, 0xFFFFU);
    menu_draw_text(pixels, 420, 76, "SELECT LEVEL", 6, 0x0000U);
    menu_draw_text(pixels, 424, 72, "SELECT LEVEL", 6, 0xFFE0U);

    for (card = 0U; card < LEVEL_COUNT; ++card) {
        int x = card_x[card];
        int border = card == selected_level ? 10 : 4;
        u16 border_color = card == selected_level ? 0xFFE0U : 0xFFFFU;

        menu_fill_rect(pixels, x, 188, 352, 356, border_color);
        menu_fill_rect(pixels, x + border, 188 + border,
                       352 - border * 2, 356 - border * 2,
                       card_color[card]);
        menu_draw_char(pixels, x + 150, 238, (char)('1' + card),
                       10, 0xFFFFU);

        /* Tiny themed silhouettes make the cards readable at a glance. */
        menu_fill_rect(pixels, x + 36, 398, 280, 18, 0x65A5U);
        menu_fill_rect(pixels, x + 36, 416, 280, 72, 0xA205U);
        if (card == 0U) {
            menu_fill_rect(pixels, x + 70, 350, 70, 16, 0xFBE0U);
            menu_fill_rect(pixels, x + 210, 326, 72, 16, 0xFBE0U);
        } else if (card == 1U) {
            menu_fill_rect(pixels, x + 42, 360, 78, 12, 0xFFFFU);
            menu_fill_rect(pixels, x + 138, 330, 78, 12, 0xFFFFU);
            menu_fill_rect(pixels, x + 234, 300, 78, 12, 0xFFFFU);
        } else {
            menu_fill_rect(pixels, x + 64, 378, 44, 20, 0xF800U);
            menu_fill_rect(pixels, x + 154, 350, 44, 48, 0xF800U);
            menu_fill_rect(pixels, x + 244, 322, 44, 76, 0xF800U);
        }
        menu_draw_text(pixels, x + 58, 500, level_configs[card].name,
                       3, 0xFFFFU);
    }

    if (loading) {
        menu_fill_rect(pixels, 458, 602, 364, 62, 0x18C3U);
        menu_draw_text(pixels, 526, 618, "LOADING", 4, 0xFFFFU);
    } else {
        menu_draw_text(pixels, 358, 610, "A D CHOOSE", 4, 0xFFFFU);
        menu_draw_text(pixels, 822, 610, "SPACE START", 4, 0xFFFFU);
    }
}

static void draw_level_select(u32 selected_level, int loading)
{
    draw_level_select_frame(MENU_FRAME0_ADDR, selected_level, loading);
    draw_level_select_frame(MENU_FRAME1_ADDR, selected_level, loading);
    draw_level_select_frame(MENU_FRAME2_ADDR, selected_level, loading);
}

static void update_level_select(
    u32 selected_level, int loading, u32 *display_frame)
{
    static const UINTPTR menu_frames[3] = {
        MENU_FRAME0_ADDR, MENU_FRAME1_ADDR, MENU_FRAME2_ADDR
    };
    u32 next_frame = (*display_frame + 1U) % 3U;

    /*
     * MM2S remains parked on the old, complete menu while MicroBlaze draws
     * the next one.  Changing the park pointer only after all pixels have
     * reached DDR makes VDMA switch at a frame boundary without ever reading
     * a framebuffer that is being modified.
     */
    draw_level_select_frame(
        menu_frames[next_frame], selected_level, loading);
    Xil_Out32(VDMA_PARK_PTR, next_frame);
    while (((Xil_In32(VDMA_PARK_PTR) >> 16) & 0x1FU) != next_frame) {
        /* VDMA changes parked frame stores only at a frame boundary. */
    }
    *display_frame = next_frame;
}

static void clear_frame(UINTPTR address)
{
    volatile u32 *words = (volatile u32 *)address;
    u32 index;

    for (index = 0; index < FRAME_BYTES / sizeof(u32); ++index) {
        words[index] = 0U;
    }
}

static int start_vdma_s2mm(void)
{
    u32 timeout;

    xil_printf("S2MM before reset: CR=0x%08x SR=0x%08x\r\n",
               (unsigned int)Xil_In32(S2MM_DMACR),
               (unsigned int)Xil_In32(S2MM_DMASR));

    Xil_Out32(S2MM_DMACR, VDMA_DMACR_RESET);
    for (timeout = 0; timeout < 1000000U; ++timeout) {
        if ((Xil_In32(S2MM_DMACR) & VDMA_DMACR_RESET) == 0U) {
            break;
        }
    }
    if (timeout == 1000000U) {
        return -1;
    }

    Xil_Out32(S2MM_DMASR, VDMA_STATUS_CLEAR_MASK);
    Xil_Out32(S2MM_HSIZE, FRAME_STRIDE);
    Xil_Out32(S2MM_FRMDLY_STRIDE, FRAME_STRIDE);
    Xil_Out32(S2MM_START_ADDR_1, FRAME0_ADDR);
    Xil_Out32(S2MM_START_ADDR_2, FRAME1_ADDR);
    Xil_Out32(S2MM_START_ADDR_3, FRAME2_ADDR);
    Xil_Out32(
        S2MM_DMACR,
        VDMA_DMACR_RUNSTOP | VDMA_DMACR_CIRCULAR |
            VDMA_DMACR_GENLOCK | VDMA_DMACR_GENLOCK_SRC
    );
    Xil_Out32(S2MM_VSIZE, FRAME_HEIGHT);

    for (timeout = 0; timeout < 1000000U; ++timeout) {
        u32 status = Xil_In32(S2MM_DMASR);
        if ((status & VDMA_ERROR_MASK) != 0U) {
            return -2;
        }
        if ((status & VDMA_DMASR_HALTED) == 0U) {
            xil_printf("S2MM after start: CR=0x%08x SR=0x%08x\r\n",
                       (unsigned int)Xil_In32(S2MM_DMACR),
                       (unsigned int)status);
            return 0;
        }
    }

    return -3;
}

static int wait_for_s2mm_frame(void)
{
    u32 timeout;

    for (timeout = 0; timeout < 100000000U; ++timeout) {
        u32 status = Xil_In32(S2MM_DMASR);
        if ((status & VDMA_ERROR_MASK) != 0U) {
            return -1;
        }
        if ((status & VDMA_FRAME_IRQ) != 0U) {
            xil_printf("S2MM first frame complete: SR=0x%08x\r\n",
                       (unsigned int)status);
            return 0;
        }
    }

    return -2;
}

static int start_vdma_mm2s(
    int dynamic_genlock, u32 frame0, u32 frame1, u32 frame2)
{
    u32 timeout;
    u32 control = VDMA_DMACR_RUNSTOP;

    xil_printf("VDMA before reset: CR=0x%08x SR=0x%08x\r\n",
               (unsigned int)Xil_In32(MM2S_DMACR),
               (unsigned int)Xil_In32(MM2S_DMASR));

    Xil_Out32(MM2S_DMACR, VDMA_DMACR_RESET);
    for (timeout = 0; timeout < 1000000U; ++timeout) {
        if ((Xil_In32(MM2S_DMACR) & VDMA_DMACR_RESET) == 0U) {
            break;
        }
    }
    if (timeout == 1000000U) {
        return -1;
    }

    // Clear sticky error and interrupt status left by reset/startup.
    // Bits 12/13 are normal frame-count/delay interrupts, not faults.
    Xil_Out32(MM2S_DMASR, VDMA_STATUS_CLEAR_MASK);

    Xil_Out32(MM2S_HSIZE, FRAME_STRIDE);
    // Gameplay uses dynamic genlock and displays the completed S2MM frame one
    // slot behind.  The pre-game menu is a CPU-drawn framebuffer and runs
    // MM2S independently while the selected level is loaded in the background.
    if (dynamic_genlock) {
        Xil_Out32(MM2S_FRMDLY_STRIDE, (1U << 24) | FRAME_STRIDE);
        control |= VDMA_DMACR_CIRCULAR |
                   VDMA_DMACR_GENLOCK | VDMA_DMACR_GENLOCK_SRC;
    } else {
        /* Park on menu frame store 0 instead of cycling through live buffers. */
        Xil_Out32(VDMA_PARK_PTR, 0U);
        Xil_Out32(MM2S_FRMDLY_STRIDE, FRAME_STRIDE);
    }
    Xil_Out32(MM2S_START_ADDR_1, frame0);
    Xil_Out32(MM2S_START_ADDR_2, frame1);
    Xil_Out32(MM2S_START_ADDR_3, frame2);
    Xil_Out32(MM2S_DMACR, control);

    // Writing VSIZE last starts the MM2S transfer.
    Xil_Out32(MM2S_VSIZE, FRAME_HEIGHT);

    for (timeout = 0; timeout < 1000000U; ++timeout) {
        u32 status = Xil_In32(MM2S_DMASR);
        if ((status & VDMA_ERROR_MASK) != 0U) {
            return -2;
        }
        if ((status & VDMA_DMASR_HALTED) == 0U) {
            xil_printf("VDMA after start: CR=0x%08x SR=0x%08x\r\n",
                       (unsigned int)Xil_In32(MM2S_DMACR),
                       (unsigned int)status);
            return 0;
        }
    }

    return -3;
}

static u32 select_level(void)
{
    u32 selected = 0U;
    u32 display_frame = 0U;
    u8 previous = 0U;

    xil_printf("Level select: A/D choose, Space starts\r\n");

    for (;;) {
        int received;
        u8 input = receive_keyboard_state(previous, &received);

        if (received) {
            if ((input & KEY_LEFT) != 0U &&
                (previous & KEY_LEFT) == 0U) {
                selected = selected == 0U ? LEVEL_COUNT - 1U : selected - 1U;
                update_level_select(selected, 0, &display_frame);
                xil_printf("Selected level %u: %s\r\n",
                           (unsigned int)(selected + 1U),
                           level_configs[selected].name);
            } else if ((input & KEY_RIGHT) != 0U &&
                (previous & KEY_RIGHT) == 0U) {
                selected = (selected + 1U) % LEVEL_COUNT;
                update_level_select(selected, 0, &display_frame);
                xil_printf("Selected level %u: %s\r\n",
                           (unsigned int)(selected + 1U),
                           level_configs[selected].name);
            }
            if ((input & KEY_JUMP) != 0U &&
                (previous & KEY_JUMP) == 0U) {
                update_level_select(selected, 1, &display_frame);
                xil_printf("Starting level %u: %s\r\n",
                           (unsigned int)(selected + 1U),
                           level_configs[selected].name);
                return selected;
            }
            previous = input;
        }
    }
}

int main(void)
{
    u32 last_mm2s_status = 0xFFFFFFFFU;
    u32 last_s2mm_status = 0xFFFFFFFFU;
    u32 selected_level;
    u32 enemy_index;
    const level_config_t *level = &level_configs[0];
    int start_status;
    int hero_x = level_configs[0].spawn_x;
    int hero_y = level_configs[0].spawn_y;
    int hero_y_fp = level_configs[0].spawn_y << POSITION_SHIFT;
    int velocity_y = 0;
    int grounded = 0;
    u32 jumps_used = 0U;
    int camera_x = 0;
    int goal_reached = 0;
    u32 coin_count = 0U;
    u32 player_health = PLAYER_HEALTH_MAX;
    u32 game_over_ticks = 0U;
    u32 invincibility_ticks = 0U;
    u32 active_sprite_slot = 0U;
    u32 sprite_slot_frame[2] = {HERO_FRAME_IDLE, HERO_FRAME_BLINK};
    u32 animation_ticks = 0U;
    int facing_left = 0;
    u8 input_state = 0U;
    u8 previous_input = 0U;
    u32 input_age = INPUT_TIMEOUT_FRAMES;
    u32 rendered_frames = 0U;
    enemy_state_t enemies[ENEMY_COUNT];

    xil_printf("\r\nSuper Mario FPGA game runtime\r\n");
    xil_printf("Clearing three 1280x720 RGB565 frames...\r\n");

    // Keep AXI4-Stream idle until S2MM is ready.  The GPIO reset value is
    // also zero, so no partial line can escape while MicroBlaze boots.
    Xil_Out32(RENDER_GPIO_TRI, 0U);
    Xil_Out32(RENDER_GPIO_DATA, 0U);

    clear_frame(FRAME0_ADDR);
    clear_frame(FRAME1_ADDR);
    clear_frame(FRAME2_ADDR);
    xil_printf("DDR3 clear complete\r\n");

    draw_level_select(0U, 0);
    start_status = start_vdma_mm2s(
        0, MENU_FRAME0_ADDR, MENU_FRAME1_ADDR, MENU_FRAME2_ADDR);
    if (start_status != 0) {
        xil_printf("ERROR: menu MM2S start failed %d, CR=0x%08x SR=0x%08x\r\n",
                   start_status,
                   (unsigned int)Xil_In32(MM2S_DMACR),
                   (unsigned int)Xil_In32(MM2S_DMASR));
        for (;;) {
        }
    }

    while (verify_sd_game_files() != 0) {
        volatile u32 retry_delay;

        xil_printf("SD: retrying initialization; renderer remains idle\r\n");
        for (retry_delay = 0U; retry_delay < 10000000U; ++retry_delay) {
        }
    }

    selected_level = select_level();
    level = &level_configs[selected_level];
    hero_x = level->spawn_x;
    hero_y = level->spawn_y;
    hero_y_fp = hero_y << POSITION_SHIFT;
    for (enemy_index = 0U; enemy_index < ENEMY_COUNT; ++enemy_index)
        enemies[enemy_index] = level->enemies[enemy_index];

    start_status = start_vdma_s2mm();
    if (start_status != 0) {
        xil_printf("ERROR: VDMA S2MM start failed %d, CR=0x%08x SR=0x%08x\r\n",
                   start_status,
                   (unsigned int)Xil_In32(S2MM_DMACR),
                   (unsigned int)Xil_In32(S2MM_DMASR));
        for (;;) {
        }
    }

    if (load_level_collision(level) != 0) {
        xil_printf("ERROR: collision map load failed\r\n");
        for (;;) {
        }
    }

    start_status = load_game_assets_to_renderer(level);
    if (start_status != 0) {
        xil_printf("ERROR: Sprite Engine asset load failed %d\r\n",
                   start_status);
        for (;;) {
        }
    }

    if (publish_enemy_attributes(enemies, camera_x) != 0) {
        for (;;) {
        }
    }

    xil_printf("S2MM ready; enabling loaded level at SOF\r\n");
    Xil_Out32(RENDER_GPIO_DATA,
              make_render_control(
                  hero_x, hero_y, camera_x, active_sprite_slot, facing_left,
                  1
              ));

    start_status = wait_for_s2mm_frame();
    if (start_status != 0) {
        xil_printf("ERROR: VDMA S2MM frame wait failed %d, SR=0x%08x\r\n",
                   start_status,
                   (unsigned int)Xil_In32(S2MM_DMASR));
        for (;;) {
        }
    }

    start_status = start_vdma_mm2s(
        1, FRAME0_ADDR, FRAME1_ADDR, FRAME2_ADDR);
    if (start_status != 0) {
        xil_printf("ERROR: VDMA start failed %d, CR=0x%08x SR=0x%08x\r\n",
                   start_status,
                   (unsigned int)Xil_In32(MM2S_DMACR),
                   (unsigned int)Xil_In32(MM2S_DMASR));
        for (;;) {
        }
    }
    xil_printf("VDMA MM2S started\r\n");

    /* HUD stays disabled throughout level selection and loading. */
    if (hud_update(coin_count, goal_reached, player_health, 0) != 0) {
        for (;;) {
        }
    }

    xil_printf("Keyboard enabled: A=left D=right Space=double jump\r\n");

    // Discard the startup frame flag. Each following flag advances the game
    // state exactly once and commits the new position for the next frame.
    Xil_Out32(S2MM_DMASR, VDMA_FRAME_IRQ);

    for (;;) {
        u32 mm2s_status = Xil_In32(MM2S_DMASR);
        u32 s2mm_status = Xil_In32(S2MM_DMASR);
        u32 s2mm_report_status = s2mm_status & ~VDMA_FRAME_IRQ;

        if (mm2s_status != last_mm2s_status) {
            xil_printf("MM2S status: 0x%08x\r\n",
                       (unsigned int)mm2s_status);
            last_mm2s_status = mm2s_status;
        }
        if (s2mm_report_status != last_s2mm_status) {
            xil_printf("S2MM status: 0x%08x\r\n",
                       (unsigned int)s2mm_status);
            last_s2mm_status = s2mm_report_status;
        }
        if ((mm2s_status & VDMA_ERROR_MASK) != 0U) {
            xil_printf("ERROR: VDMA MM2S fault 0x%08x\r\n",
                       (unsigned int)mm2s_status);
            for (;;) {
            }
        }
        if ((s2mm_status & VDMA_ERROR_MASK) != 0U) {
            xil_printf("ERROR: VDMA S2MM fault 0x%08x\r\n",
                       (unsigned int)s2mm_status);
            for (;;) {
            }
        }

        if ((s2mm_status & VDMA_FRAME_IRQ) != 0U) {
            int uart_received;

            Xil_Out32(S2MM_DMASR, VDMA_FRAME_IRQ);

            input_state = receive_keyboard_state(
                input_state, &uart_received
            );
            if (uart_received) {
                input_age = 0U;
            } else if (input_age < INPUT_TIMEOUT_FRAMES) {
                ++input_age;
            } else {
                input_state = 0U;
            }

            if (game_over_ticks > 0U) {
                input_state = 0U;
                --game_over_ticks;
                if (game_over_ticks == 0U) {
                    player_health = PLAYER_HEALTH_MAX;
                    hero_x = level->spawn_x;
                    hero_y = level->spawn_y;
                    hero_y_fp = hero_y << POSITION_SHIFT;
                    velocity_y = 0;
                    grounded = 0;
                    jumps_used = 0U;
                    xil_printf("GAME OVER animation complete; restarting\r\n");
                    if (hud_update(coin_count, goal_reached,
                                   player_health, 0) != 0) {
                        for (;;) {
                        }
                    }
                }
            }

            if (game_over_ticks == 0U && invincibility_ticks > 0U) {
                --invincibility_ticks;
                if (invincibility_ticks == 0U) {
                    xil_printf("Star power expired\r\n");
                    if (hud_update(coin_count, goal_reached,
                                   player_health, 0) != 0) {
                        for (;;) {
                        }
                    }
                }
            }

            if (game_over_ticks == 0U && !goal_reached &&
                ((input_state & KEY_LEFT) != 0U) &&
                ((input_state & KEY_RIGHT) == 0U)) {
                move_hero_horizontal(&hero_x, hero_y, -MOVE_PIXELS);
                facing_left = 1;
            } else if (game_over_ticks == 0U && !goal_reached &&
                       ((input_state & KEY_RIGHT) != 0U) &&
                       ((input_state & KEY_LEFT) == 0U)) {
                move_hero_horizontal(&hero_x, hero_y, MOVE_PIXELS);
                facing_left = 0;
            }

            if (game_over_ticks == 0U && !goal_reached &&
                ((input_state & KEY_JUMP) != 0U) &&
                ((previous_input & KEY_JUMP) == 0U) && jumps_used < 2U) {
                velocity_y = jumps_used == 0U
                    ? JUMP_VELOCITY : DOUBLE_JUMP_VELOCITY;
                grounded = 0;
                ++jumps_used;
            }

            if (game_over_ticks == 0U) {
                move_hero_vertical(
                    hero_x, &hero_y, &hero_y_fp, &velocity_y, &grounded
                );
                if (grounded)
                    jumps_used = 0U;
            }
            if (game_over_ticks == 0U) {
                u32 previous_coin_count = coin_count;
                coin_count = collect_coins(hero_x, hero_y, coin_count);
                if (coin_count != previous_coin_count &&
                    hud_update(coin_count, goal_reached,
                               player_health,
                               invincibility_ticks > 0U) != 0) {
                    for (;;) {
                    }
                }
                if (collect_items(
                        hero_x, hero_y, &player_health,
                        &invincibility_ticks)) {
                    if (hud_update(coin_count, goal_reached,
                                   player_health,
                                   invincibility_ticks > 0U) != 0) {
                        for (;;) {
                        }
                    }
                }
            }

            if (collision_at(hero_x + HERO_WIDTH / 2,
                             hero_y + HERO_HEIGHT - 1) == COLLISION_HAZARD ||
                hero_y >= WORLD_HEIGHT) {
                xil_printf("Hazard: respawning hero\r\n");
                hero_x = level->spawn_x;
                hero_y = level->spawn_y;
                hero_y_fp = hero_y << POSITION_SHIFT;
                velocity_y = 0;
                grounded = 0;
                jumps_used = 0U;
                if (invincibility_ticks == 0U && player_health > 0U)
                    --player_health;
                if (player_health == 0U) {
                    xil_printf("GAME OVER: playing failure animation\r\n");
                    game_over_ticks = GAME_OVER_HOLD_FRAMES;
                }
                if (hud_update(coin_count, goal_reached,
                               player_health,
                               invincibility_ticks > 0U) != 0) {
                    for (;;) {
                    }
                }
            } else if (game_over_ticks == 0U && !goal_reached &&
                       (hero_touches_collision(
                            hero_x, hero_y, COLLISION_GOAL) ||
                        hero_x >= level->goal_trigger_x)) {
                if (!goal_reached) {
                    xil_printf("Goal reached at world x=%d, coins=%u/%u!\r\n",
                               hero_x,
                               (unsigned int)coin_count,
                               (unsigned int)LEVEL_COIN_TOTAL);
                    goal_reached = 1;
                    if (hud_update(coin_count, goal_reached,
                                   player_health,
                                   invincibility_ticks > 0U) != 0) {
                        for (;;) {
                        }
                    }
                }
            }

            if (game_over_ticks == 0U && !goal_reached) {
                u32 enemy_index;
                int hit_enemy = 0;

                if ((rendered_frames % ENEMY_MOVE_DIVIDER) == 0U)
                    update_enemies(enemies);
                for (enemy_index = 0U;
                     enemy_index < ENEMY_COUNT; ++enemy_index) {
                    if (invincibility_ticks == 0U &&
                        hero_hits_enemy(hero_x, hero_y,
                                        &enemies[enemy_index])) {
                        hit_enemy = 1;
                        break;
                    }
                }
                if (hit_enemy) {
                    xil_printf("Enemy hit: respawning hero\r\n");
                    hero_x = level->spawn_x;
                    hero_y = level->spawn_y;
                    hero_y_fp = hero_y << POSITION_SHIFT;
                    velocity_y = 0;
                    grounded = 0;
                    jumps_used = 0U;
                    if (player_health > 0U)
                        --player_health;
                    if (player_health == 0U) {
                        xil_printf(
                            "GAME OVER: playing failure animation\r\n");
                        game_over_ticks = GAME_OVER_HOLD_FRAMES;
                    }
                    if (hud_update(coin_count, goal_reached,
                                   player_health,
                                   invincibility_ticks > 0U) != 0) {
                        for (;;) {
                        }
                    }
                }
            }

            {
                int walking = grounded &&
                    (((input_state & KEY_LEFT) != 0U) ^
                     ((input_state & KEY_RIGHT) != 0U));
                u32 desired_frame;

                if (game_over_ticks > 0U) {
                    desired_frame =
                        ((game_over_ticks / GAME_OVER_ANIMATION_TICKS) & 1U)
                        ? HERO_FRAME_HURT : HERO_FRAME_CROUCH;
                    animation_ticks = 0U;
                } else if (goal_reached) {
                    desired_frame = HERO_FRAME_VICTORY;
                    animation_ticks = 0U;
                } else if (!grounded) {
                    desired_frame = velocity_y < 0
                        ? HERO_FRAME_JUMP_RISE
                        : HERO_FRAME_JUMP_FALL;
                    animation_ticks = 0U;
                } else if (walking) {
                    desired_frame = HERO_FRAME_WALK_0 +
                        (animation_ticks / WALK_FRAME_TICKS) %
                            HERO_FRAME_WALK_COUNT;
                    ++animation_ticks;
                } else {
                    animation_ticks = 0U;
                    desired_frame =
                        (rendered_frames % BLINK_PERIOD_FRAMES) <
                            BLINK_HOLD_FRAMES
                        ? HERO_FRAME_BLINK
                        : HERO_FRAME_IDLE;
                }

                if (sprite_slot_frame[active_sprite_slot] != desired_frame) {
                    u32 next_slot = active_sprite_slot ^ 1U;

                    if (sprite_slot_frame[next_slot] != desired_frame) {
                        if (upload_cached_hero_frame(
                                desired_frame, next_slot) != 0) {
                            xil_printf(
                                "ERROR: animation load frame=%u slot=%u\r\n",
                                (unsigned int)desired_frame,
                                (unsigned int)next_slot);
                            for (;;) {
                            }
                        }
                        sprite_slot_frame[next_slot] = desired_frame;
                    }
                    active_sprite_slot = next_slot;
                }
            }

            camera_x = camera_for_hero(hero_x);
            if (publish_enemy_attributes(enemies, camera_x) != 0) {
                for (;;) {
                }
            }
            Xil_Out32(RENDER_GPIO_DATA,
                      make_render_control(
                          hero_x - camera_x,
                          hero_y,
                          camera_x,
                          active_sprite_slot,
                          facing_left,
                          invincibility_ticks == 0U ||
                              ((invincibility_ticks >> 2) & 1U) != 0U
                      ));

            previous_input = input_state;

            ++rendered_frames;
            if ((rendered_frames & 0xFFU) == 0U) {
                xil_printf("Interactive OK: frames=%u input=0x%02x "
                           "world_x=%d screen_x=%d y=%d camera=%d coins=%u "
                           "hp=%u star=%u anim=%u bank=%u flip=%u\r\n",
                           (unsigned int)rendered_frames,
                           (unsigned int)input_state,
                           hero_x,
                           hero_x - camera_x,
                           hero_y,
                           camera_x,
                           (unsigned int)coin_count,
                           (unsigned int)player_health,
                           (unsigned int)invincibility_ticks,
                           (unsigned int)sprite_slot_frame[active_sprite_slot],
                           (unsigned int)active_sprite_slot,
                           (unsigned int)facing_left);
            }
        }
    }
}
