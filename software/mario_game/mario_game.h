#ifndef MARIO_GAME_H
#define MARIO_GAME_H

#include "mario_assets.h"
#include "xaxidma.h"
#include "xil_types.h"

#define MARIO_MAX_ENEMIES 5U

enum {
    MARIO_INPUT_LEFT  = 0x01U,
    MARIO_INPUT_RIGHT = 0x02U,
    MARIO_INPUT_JUMP  = 0x04U
};

typedef enum {
    ENEMY_BEETLE = 0,
    ENEMY_SLIME,
    ENEMY_BAT,
    ENEMY_TURTLE
} mario_enemy_type_t;

typedef struct {
    mario_enemy_type_t type;
    s32 x;
    s32 y;
    s32 velocity_x;
    s32 velocity_y;
    s32 patrol_min;
    s32 patrol_max;
    u8 alive;
    u8 facing_left;
    u8 loaded_frame;
    u8 phase;
} mario_enemy_t;

typedef struct {
    mario_assets_t *assets;
    XAxiDma *dma;
    s32 hero_x;
    s32 hero_y;
    s32 hero_velocity_x;
    s32 hero_velocity_y;
    s32 checkpoint_x;
    s32 checkpoint_y;
    u32 camera_x;
    u32 tick;
    u8 grounded;
    u8 facing_left;
    u8 previous_input;
    u8 hero_loaded_frame;
    u8 won;
    mario_enemy_t enemies[MARIO_MAX_ENEMIES];
} mario_game_t;

int mario_game_init(
    mario_game_t *game,
    mario_assets_t *assets,
    XAxiDma *dma
);

int mario_game_update(mario_game_t *game, u8 input_state);

#endif
