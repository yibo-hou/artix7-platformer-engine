#ifndef SPRITE_ENGINE_REGS_H
#define SPRITE_ENGINE_REGS_H

#include <stdint.h>

#define SPR_REG32(base, offset) \
    (*(volatile uint32_t *)((uintptr_t)(base) + (offset)))

#define SPR_CONTROL_OFFSET       0x000u
#define SPR_STATUS_OFFSET        0x004u
#define SPR_RENDER_CONTROL_OFFSET 0x008u
#define SPR_ASSET_DEST_OFFSET    0x00Cu
#define SPR_SCROLL_OFFSET        0x014u
#define SPR_ATTR_BASE_OFFSET     0x040u
#define SPR_PALETTE_BASE_OFFSET  0x080u

#define SPR_CONTROL_CLEAR_STATUS (1u << 0)
#define SPR_STATUS_ASSET_BUSY    (1u << 1)
#define SPR_STATUS_ASSET_DONE    (1u << 2)
#define SPR_STATUS_ASSET_ERROR   (1u << 3)
#define SPR_STATUS_CFG_FULL      (1u << 4)

#define SPR_ASSET_TILEMAP          0u
#define SPR_ASSET_TILE_GRAPHICS    1u
#define SPR_ASSET_SPRITE_GRAPHICS  2u
#define SPR_ASSET_PALETTE          3u

static inline uint32_t sprite_attr_pack(
    unsigned enable,
    unsigned x,
    unsigned y,
    unsigned flip_x,
    unsigned flip_y)
{
    return ((enable & 1u) << 0) |
           ((x & 0x7FFu) << 1) |
           ((y & 0x3FFu) << 12) |
           ((flip_x & 1u) << 22) |
           ((flip_y & 1u) << 23);
}

static inline void sprite_set_attr(
    uintptr_t base,
    unsigned slot,
    uint32_t packed_attr)
{
    SPR_REG32(base, SPR_ATTR_BASE_OFFSET + ((slot & 15u) * 4u)) =
        packed_attr;
}

static inline void sprite_set_scroll(
    uintptr_t base,
    unsigned x,
    unsigned y)
{
    SPR_REG32(base, SPR_SCROLL_OFFSET) =
        (x & 0x7FFu) | ((y & 0x3FFu) << 11);
}

static inline void sprite_set_render_enable(uintptr_t base, unsigned enable)
{
    SPR_REG32(base, SPR_RENDER_CONTROL_OFFSET) = enable & 1u;
}

static inline void sprite_set_palette(
    uintptr_t base,
    unsigned index,
    uint16_t rgb565)
{
    SPR_REG32(base, SPR_PALETTE_BASE_OFFSET + ((index & 15u) * 4u)) =
        rgb565;
}

static inline void sprite_asset_set_destination(
    uintptr_t base,
    unsigned destination_kind,
    unsigned destination_address)
{
    SPR_REG32(base, SPR_ASSET_DEST_OFFSET) =
        ((destination_kind & 3u) << 30) |
        (destination_address & 0xFFFFu);
}

static inline void sprite_asset_clear_status(uintptr_t base)
{
    SPR_REG32(base, SPR_CONTROL_OFFSET) = SPR_CONTROL_CLEAR_STATUS;
}

#endif
