#ifndef MARIO_FRAMEBUFFER_H
#define MARIO_FRAMEBUFFER_H

#include "xaxivdma.h"

typedef enum {
    MARIO_FRAMEBUFFER_BLACK = 0,
    MARIO_FRAMEBUFFER_COLOR_BARS = 1
} mario_framebuffer_pattern_t;

/*
 * Minimum hardware bring-up path. Fill all frame stores in software and start
 * MM2S only, with genlock disabled so it cannot wait for an inactive S2MM
 * channel.
 */
int mario_framebuffer_init_mm2s(
    XAxiVdma *vdma,
    mario_framebuffer_pattern_t pattern
);

/*
 * Initialize both AXI VDMA channels for 1280x720 RGB565 triple buffering.
 * Vivado must configure S2MM as genlock master and MM2S as genlock slave with
 * a one-frame delay.
 */
int mario_framebuffer_init(XAxiVdma *vdma);

#endif
