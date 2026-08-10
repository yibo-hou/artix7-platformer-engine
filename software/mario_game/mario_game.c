#include "mario_game.h"

#include <string.h>

#include "platform_config.h"
#include "sprite_engine_regs.h"

#define FP_SHIFT 8
#define FP_ONE   (1 << FP_SHIFT)
#define TO_FP(x) ((s32)(x) << FP_SHIFT)
#define FROM_FP(x) ((s32)(x) >> FP_SHIFT)

#define SCREEN_WIDTH  1280
#define SCREEN_HEIGHT 720
#define WORLD_WIDTH   ((s32)(MARIO_LEVEL_WIDTH_TILES * 16U))
#define WORLD_HEIGHT  ((s32)(MARIO_LEVEL_HEIGHT_TILES * 16U))
#define MAX_CAMERA_X  (WORLD_WIDTH - SCREEN_WIDTH)

#define HERO_WIDTH         32
#define HERO_HEIGHT        32
#define HERO_LEFT_INSET    4
#define HERO_RIGHT_INSET   4
#define HERO_TOP_INSET     2
#define HERO_RUN_SPEED     (3 * FP_ONE)
#define HERO_ACCEL         96
#define HERO_FRICTION      72
#define HERO_GRAVITY       115
#define HERO_MAX_FALL      (9 * FP_ONE)
#define HERO_JUMP_SPEED    (-8 * FP_ONE - FP_ONE / 2)
#define HERO_STOMP_BOUNCE  (-5 * FP_ONE)

#define COLLISION_EMPTY   0U
#define COLLISION_SOLID   1U
#define COLLISION_HAZARD  2U
#define COLLISION_GOAL    3U
#define COLLISION_REWARD  4U

#define TILE_USED_BLOCK 22U

typedef struct {
    mario_enemy_type_t type;
    s32 x;
    s32 y;
    s32 patrol_min;
    s32 patrol_max;
} enemy_spawn_t;

static const enemy_spawn_t enemy_spawns[MARIO_MAX_ENEMIES] = {
    {ENEMY_BEETLE, 26 * 16, 41 * 16, 24 * 16, 28 * 16},
    {ENEMY_SLIME,  43 * 16, 41 * 16, 39 * 16, 47 * 16},
    {ENEMY_BAT,    59 * 16, 29 * 16, 54 * 16, 64 * 16},
    {ENEMY_TURTLE, 81 * 16, 41 * 16, 78 * 16, 90 * 16},
    {ENEMY_BAT,   110 * 16, 29 * 16, 106 * 16, 118 * 16}
};

static s32 absolute_s32(s32 value)
{
    return value < 0 ? -value : value;
}

static u32 tile_offset(u32 tile_x, u32 tile_y)
{
    return tile_y * MARIO_LEVEL_WIDTH_TILES + tile_x;
}

static u8 collision_at(const mario_game_t *game, s32 pixel_x, s32 pixel_y)
{
    u32 tile_x;
    u32 tile_y;

    if (pixel_y < 0) {
        return COLLISION_EMPTY;
    }
    if (pixel_x < 0 || pixel_x >= WORLD_WIDTH) {
        return COLLISION_SOLID;
    }
    if (pixel_y >= WORLD_HEIGHT) {
        return COLLISION_HAZARD;
    }

    tile_x = (u32)pixel_x >> 4;
    tile_y = (u32)pixel_y >> 4;
    return game->assets->level_collision[tile_offset(tile_x, tile_y)];
}

static int is_solid(u8 collision)
{
    return collision == COLLISION_SOLID ||
           collision == COLLISION_REWARD;
}

static void respawn_hero(mario_game_t *game)
{
    game->hero_x = game->checkpoint_x;
    game->hero_y = game->checkpoint_y;
    game->hero_velocity_x = 0;
    game->hero_velocity_y = 0;
    game->grounded = 0U;
}

static int hit_reward_block(mario_game_t *game, s32 pixel_x, s32 pixel_y)
{
    u32 tile_x;
    u32 tile_y;
    u32 offset;

    if (collision_at(game, pixel_x, pixel_y) != COLLISION_REWARD) {
        return 0;
    }
    tile_x = (u32)pixel_x >> 4;
    tile_y = (u32)pixel_y >> 4;
    offset = tile_offset(tile_x, tile_y);
    game->assets->level_tiles[offset] = TILE_USED_BLOCK;
    return mario_assets_upload_map_region(game->assets, game->dma, offset);
}

static int move_hero_horizontal(mario_game_t *game)
{
    s32 x;
    s32 y = FROM_FP(game->hero_y);
    s32 sample_top = y + HERO_TOP_INSET + 2;
    s32 sample_bottom = y + HERO_HEIGHT - 2;
    u8 first;
    u8 second;

    game->hero_x += game->hero_velocity_x;
    x = FROM_FP(game->hero_x);

    if (game->hero_velocity_x > 0) {
        s32 right = x + HERO_WIDTH - HERO_RIGHT_INSET - 1;
        first = collision_at(game, right, sample_top);
        second = collision_at(game, right, sample_bottom);
        if (is_solid(first) || is_solid(second)) {
            game->hero_x =
                TO_FP(((right >> 4) << 4) -
                      (HERO_WIDTH - HERO_RIGHT_INSET));
            game->hero_velocity_x = 0;
        }
    } else if (game->hero_velocity_x < 0) {
        s32 left = x + HERO_LEFT_INSET;
        first = collision_at(game, left, sample_top);
        second = collision_at(game, left, sample_bottom);
        if (is_solid(first) || is_solid(second)) {
            game->hero_x =
                TO_FP((((left >> 4) + 1) << 4) - HERO_LEFT_INSET);
            game->hero_velocity_x = 0;
        }
    }
    return 0;
}

static int move_hero_vertical(mario_game_t *game)
{
    s32 x = FROM_FP(game->hero_x);
    s32 y;
    s32 sample_left = x + HERO_LEFT_INSET + 2;
    s32 sample_right = x + HERO_WIDTH - HERO_RIGHT_INSET - 2;
    u8 first;
    u8 second;
    int result;

    game->hero_velocity_y += HERO_GRAVITY;
    if (game->hero_velocity_y > HERO_MAX_FALL) {
        game->hero_velocity_y = HERO_MAX_FALL;
    }
    game->hero_y += game->hero_velocity_y;
    y = FROM_FP(game->hero_y);
    game->grounded = 0U;

    if (game->hero_velocity_y >= 0) {
        s32 bottom = y + HERO_HEIGHT - 1;
        first = collision_at(game, sample_left, bottom);
        second = collision_at(game, sample_right, bottom);
        if (is_solid(first) || is_solid(second)) {
            game->hero_y = TO_FP(((bottom >> 4) << 4) - HERO_HEIGHT);
            game->hero_velocity_y = 0;
            game->grounded = 1U;
        } else {
            first = collision_at(game, sample_left, bottom + 1);
            second = collision_at(game, sample_right, bottom + 1);
            if (is_solid(first) || is_solid(second)) {
                game->hero_velocity_y = 0;
                game->grounded = 1U;
            }
        }
    } else {
        s32 top = y + HERO_TOP_INSET;
        first = collision_at(game, sample_left, top);
        second = collision_at(game, sample_right, top);
        if (is_solid(first) || is_solid(second)) {
            game->hero_y =
                TO_FP((((top >> 4) + 1) << 4) - HERO_TOP_INSET);
            game->hero_velocity_y = 0;
            result = hit_reward_block(game, sample_left, top);
            if (result != 0) return result;
            if ((sample_left >> 4) != (sample_right >> 4)) {
                result = hit_reward_block(game, sample_right, top);
                if (result != 0) return result;
            }
        }
    }
    return 0;
}

static int rectangles_overlap(
    s32 ax,
    s32 ay,
    s32 aw,
    s32 ah,
    s32 bx,
    s32 by,
    s32 bw,
    s32 bh)
{
    return ax < bx + bw && ax + aw > bx &&
           ay < by + bh && ay + ah > by;
}

static void update_enemy(mario_game_t *game, mario_enemy_t *enemy)
{
    s32 speed;

    if (!enemy->alive) {
        return;
    }

    switch (enemy->type) {
    case ENEMY_BEETLE:
        speed = FP_ONE;
        enemy->velocity_x = enemy->facing_left ? -speed : speed;
        enemy->x += enemy->velocity_x;
        break;
    case ENEMY_TURTLE:
        speed = FP_ONE / 2;
        enemy->velocity_x = enemy->facing_left ? -speed : speed;
        enemy->x += enemy->velocity_x;
        break;
    case ENEMY_SLIME:
        enemy->phase++;
        if (enemy->phase == 1U) {
            enemy->velocity_y = -4 * FP_ONE;
            enemy->velocity_x =
                FROM_FP(game->hero_x) < FROM_FP(enemy->x)
                    ? -FP_ONE / 2
                    : FP_ONE / 2;
        }
        enemy->velocity_y += HERO_GRAVITY / 2;
        enemy->x += enemy->velocity_x;
        enemy->y += enemy->velocity_y;
        if (FROM_FP(enemy->y) >= enemy_spawns[1].y) {
            enemy->y = TO_FP(enemy_spawns[1].y);
            enemy->velocity_y = 0;
            if (enemy->phase >= 90U) {
                enemy->phase = 0U;
            }
        }
        break;
    case ENEMY_BAT:
        enemy->velocity_x = enemy->facing_left ? -FP_ONE : FP_ONE;
        enemy->x += enemy->velocity_x;
        enemy->phase++;
        enemy->y += (enemy->phase & 16U) ? FP_ONE / 4 : -FP_ONE / 4;
        break;
    }

    if (enemy->x < enemy->patrol_min) {
        enemy->x = enemy->patrol_min;
        enemy->facing_left = 0U;
    } else if (enemy->x > enemy->patrol_max) {
        enemy->x = enemy->patrol_max;
        enemy->facing_left = 1U;
    }
}

static void update_enemy_collisions(mario_game_t *game)
{
    u32 index;
    s32 hero_x = FROM_FP(game->hero_x);
    s32 hero_y = FROM_FP(game->hero_y);

    for (index = 0; index < MARIO_MAX_ENEMIES; ++index) {
        mario_enemy_t *enemy = &game->enemies[index];
        s32 enemy_x;
        s32 enemy_y;

        if (!enemy->alive) {
            continue;
        }
        enemy_x = FROM_FP(enemy->x);
        enemy_y = FROM_FP(enemy->y);
        if (!rectangles_overlap(
                hero_x + 5, hero_y + 3, 22, 28,
                enemy_x + 3, enemy_y + 3, 26, 29)) {
            continue;
        }

        if (game->hero_velocity_y > 0 &&
            hero_y + HERO_HEIGHT - enemy_y < 14) {
            enemy->alive = 0U;
            game->hero_velocity_y = HERO_STOMP_BOUNCE;
        } else {
            respawn_hero(game);
        }
    }
}

static u8 enemy_animation_frame(const mario_game_t *game,
                                const mario_enemy_t *enemy)
{
    u8 base;
    switch (enemy->type) {
    case ENEMY_BEETLE: base = 0U; break;
    case ENEMY_SLIME:  base = 4U; break;
    case ENEMY_BAT:    base = 8U; break;
    default:           base = 12U; break;
    }
    return base + (u8)((game->tick / 8U) % 3U);
}

static u8 hero_animation_frame(const mario_game_t *game)
{
    if (game->won) {
        return 14U;
    }
    if (!game->grounded) {
        return game->hero_velocity_y < 0 ? 9U : 10U;
    }
    if (absolute_s32(game->hero_velocity_x) >= 2 * FP_ONE) {
        return 6U + (u8)((game->tick / 4U) % 3U);
    }
    if (game->hero_velocity_x != 0) {
        return 2U + (u8)((game->tick / 6U) % 4U);
    }
    return (game->tick % 240U) == 0U ? 1U : 0U;
}

static int update_animation_assets(mario_game_t *game)
{
    u8 frame;
    u32 index;
    int result;

    frame = hero_animation_frame(game);
    if (frame != game->hero_loaded_frame) {
        result = mario_assets_upload_hero_frame(
            game->assets, game->dma, frame);
        if (result != 0) return result;
        game->hero_loaded_frame = frame;
    }

    for (index = 0; index < MARIO_MAX_ENEMIES; ++index) {
        mario_enemy_t *enemy = &game->enemies[index];
        if (!enemy->alive) {
            continue;
        }
        frame = enemy_animation_frame(game, enemy);
        if (frame != enemy->loaded_frame) {
            result = mario_assets_upload_enemy_frame(
                game->assets, game->dma, (u8)(index + 1U), frame);
            if (result != 0) return result;
            enemy->loaded_frame = frame;
        }
    }
    return 0;
}

static void commit_sprite_state(mario_game_t *game)
{
    u32 index;
    s32 screen_x;
    s32 screen_y;

    sprite_set_scroll(MARIO_SPRITE_CTRL_BASEADDR, game->camera_x, 0U);

    screen_x = FROM_FP(game->hero_x) - (s32)game->camera_x;
    screen_y = FROM_FP(game->hero_y);
    sprite_set_attr(
        MARIO_SPRITE_CTRL_BASEADDR,
        0U,
        sprite_attr_pack(1U, (u32)screen_x, (u32)screen_y,
                         game->facing_left, 0U)
    );

    for (index = 0; index < MARIO_MAX_ENEMIES; ++index) {
        mario_enemy_t *enemy = &game->enemies[index];
        u32 visible;
        screen_x = FROM_FP(enemy->x) - (s32)game->camera_x;
        screen_y = FROM_FP(enemy->y);
        visible = enemy->alive &&
                  screen_x > -HERO_WIDTH && screen_x < SCREEN_WIDTH &&
                  screen_y > -HERO_HEIGHT && screen_y < SCREEN_HEIGHT;
        sprite_set_attr(
            MARIO_SPRITE_CTRL_BASEADDR,
            index + 1U,
            sprite_attr_pack(
                visible,
                visible ? (u32)screen_x : 0U,
                visible ? (u32)screen_y : 0U,
                enemy->facing_left,
                0U)
        );
    }
}

int mario_game_init(
    mario_game_t *game,
    mario_assets_t *assets,
    XAxiDma *dma)
{
    u32 index;
    int result;

    if (game == NULL || assets == NULL || dma == NULL) {
        return -1;
    }
    memset(game, 0, sizeof(*game));
    game->assets = assets;
    game->dma = dma;
    game->checkpoint_x = TO_FP(3 * 16);
    game->checkpoint_y = TO_FP(40 * 16);
    respawn_hero(game);
    game->hero_loaded_frame = 0U;

    for (index = 0; index < MARIO_MAX_ENEMIES; ++index) {
        mario_enemy_t *enemy = &game->enemies[index];
        enemy->type = enemy_spawns[index].type;
        enemy->x = TO_FP(enemy_spawns[index].x);
        enemy->y = TO_FP(enemy_spawns[index].y);
        enemy->patrol_min = TO_FP(enemy_spawns[index].patrol_min);
        enemy->patrol_max = TO_FP(enemy_spawns[index].patrol_max);
        enemy->alive = 1U;
        enemy->facing_left = 1U;
        enemy->loaded_frame = 0xFFU;
        enemy->phase = (u8)(index * 13U);

        result = mario_assets_upload_enemy_frame(
            assets,
            dma,
            (u8)(index + 1U),
            enemy_animation_frame(game, enemy)
        );
        if (result != 0) return result;
        enemy->loaded_frame = enemy_animation_frame(game, enemy);
    }

    commit_sprite_state(game);
    return 0;
}

int mario_game_update(mario_game_t *game, u8 input_state)
{
    s32 hero_x;
    s32 hero_y;
    s32 desired_camera;
    u32 index;
    u8 feet_collision;
    int result;

    if (game == NULL || game->won) {
        return 0;
    }

    if ((input_state & MARIO_INPUT_LEFT) &&
        !(input_state & MARIO_INPUT_RIGHT)) {
        game->hero_velocity_x -= HERO_ACCEL;
        if (game->hero_velocity_x < -HERO_RUN_SPEED) {
            game->hero_velocity_x = -HERO_RUN_SPEED;
        }
        game->facing_left = 1U;
    } else if ((input_state & MARIO_INPUT_RIGHT) &&
               !(input_state & MARIO_INPUT_LEFT)) {
        game->hero_velocity_x += HERO_ACCEL;
        if (game->hero_velocity_x > HERO_RUN_SPEED) {
            game->hero_velocity_x = HERO_RUN_SPEED;
        }
        game->facing_left = 0U;
    } else if (game->hero_velocity_x > 0) {
        game->hero_velocity_x -= HERO_FRICTION;
        if (game->hero_velocity_x < 0) game->hero_velocity_x = 0;
    } else if (game->hero_velocity_x < 0) {
        game->hero_velocity_x += HERO_FRICTION;
        if (game->hero_velocity_x > 0) game->hero_velocity_x = 0;
    }

    if ((input_state & MARIO_INPUT_JUMP) &&
        !(game->previous_input & MARIO_INPUT_JUMP) &&
        game->grounded) {
        game->hero_velocity_y = HERO_JUMP_SPEED;
        game->grounded = 0U;
    }
    game->previous_input = input_state;

    result = move_hero_horizontal(game);
    if (result != 0) return result;
    result = move_hero_vertical(game);
    if (result != 0) return result;

    hero_x = FROM_FP(game->hero_x);
    hero_y = FROM_FP(game->hero_y);
    feet_collision = collision_at(
        game, hero_x + HERO_WIDTH / 2, hero_y + HERO_HEIGHT - 1);
    if (feet_collision == COLLISION_HAZARD || hero_y >= WORLD_HEIGHT) {
        respawn_hero(game);
    } else if (feet_collision == COLLISION_GOAL) {
        game->won = 1U;
    }

    for (index = 0; index < MARIO_MAX_ENEMIES; ++index) {
        update_enemy(game, &game->enemies[index]);
    }
    update_enemy_collisions(game);

    hero_x = FROM_FP(game->hero_x);
    desired_camera = hero_x - 400;
    if (desired_camera < 0) desired_camera = 0;
    if (desired_camera > MAX_CAMERA_X) desired_camera = MAX_CAMERA_X;
    game->camera_x = (u32)desired_camera;

    result = update_animation_assets(game);
    if (result != 0) return result;
    commit_sprite_state(game);
    game->tick++;
    return 0;
}
