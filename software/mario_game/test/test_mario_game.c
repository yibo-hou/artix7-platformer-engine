#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#include "mario_game.h"
#include "mock_support.h"

uint32_t mock_regs[256];
static unsigned hero_uploads;
static unsigned enemy_uploads;
static unsigned map_uploads;

int mario_assets_upload_hero_frame(
    mario_assets_t *assets, XAxiDma *dma, u8 frame)
{
    (void)assets;
    (void)dma;
    (void)frame;
    hero_uploads++;
    return 0;
}

int mario_assets_upload_enemy_frame(
    mario_assets_t *assets, XAxiDma *dma, u8 slot, u8 frame)
{
    (void)assets;
    (void)dma;
    (void)slot;
    (void)frame;
    enemy_uploads++;
    return 0;
}

int mario_assets_upload_map_region(
    mario_assets_t *assets, XAxiDma *dma, u32 offset)
{
    (void)assets;
    (void)dma;
    (void)offset;
    map_uploads++;
    return 0;
}

static void read_file(const char *path, u8 *buffer, size_t size)
{
    FILE *file = fopen(path, "rb");
    assert(file != NULL);
    assert(fread(buffer, 1, size, file) == size);
    fclose(file);
}

int main(void)
{
    static u8 map[MARIO_LEVEL_CELLS];
    static u8 collision[MARIO_LEVEL_CELLS];
    static u8 dummy_sheet[MARIO_SPRITE_SHEET_BYTES];
    mario_assets_t assets = {
        .palette = dummy_sheet,
        .tiles = dummy_sheet,
        .hero_frames = dummy_sheet,
        .enemy_frames = dummy_sheet,
        .level_tiles = map,
        .level_collision = collision
    };
    XAxiDma dma;
    mario_game_t game;
    s32 initial_x;
    s32 grounded_y;
    unsigned tick;

    read_file("assets/maps/level_01_tiles.bin", map, sizeof(map));
    read_file("assets/maps/level_01_collision.bin",
              collision, sizeof(collision));

    assert(mario_game_init(&game, &assets, &dma) == 0);
    assert(enemy_uploads == MARIO_MAX_ENEMIES);

    initial_x = game.hero_x;
    for (tick = 0; tick < 90; ++tick)
        assert(mario_game_update(&game, MARIO_INPUT_RIGHT) == 0);
    assert(game.hero_x > initial_x);
    assert(game.grounded);

    grounded_y = game.hero_y;
    assert(mario_game_update(&game, MARIO_INPUT_JUMP) == 0);
    assert(mario_game_update(&game, 0U) == 0);
    assert(game.hero_y < grounded_y);

    for (tick = 0; tick < 120; ++tick)
        assert(mario_game_update(&game, 0U) == 0);
    assert(game.grounded);

    printf("PASS: movement, ground collision, jump, assets and sprite writes\n");
    printf("hero uploads=%u enemy uploads=%u map uploads=%u\n",
           hero_uploads, enemy_uploads, map_uploads);
    return 0;
}
