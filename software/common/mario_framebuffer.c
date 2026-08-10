#include "mario_framebuffer.h"

#include <string.h>

#include "platform_config.h"
#include "xil_cache.h"
#include "xstatus.h"

static UINTPTR frame_addresses[XAXIVDMA_MAX_FRAMESTORE];

static const u16 color_bars[8] = {
    0xFFFFU, 0xFFE0U, 0x07FFU, 0x07E0U,
    0xF81FU, 0xF800U, 0x001FU, 0x0000U
};

static void initialize_frame_addresses(void)
{
    u32 index;

    frame_addresses[0] = MARIO_FRAME0_ADDR;
    frame_addresses[1] = MARIO_FRAME1_ADDR;
    frame_addresses[2] = MARIO_FRAME2_ADDR;
    for (index = MARIO_FRAME_STORE_COUNT;
         index < XAXIVDMA_MAX_FRAMESTORE;
         ++index) {
        frame_addresses[index] = frame_addresses[2];
    }
}

static void fill_frame_stores(mario_framebuffer_pattern_t pattern)
{
    u32 frame;

    if (pattern == MARIO_FRAMEBUFFER_BLACK) {
        for (frame = 0; frame < MARIO_FRAME_STORE_COUNT; ++frame) {
            memset((void *)frame_addresses[frame], 0, MARIO_FRAME_BYTES);
            Xil_DCacheFlushRange(frame_addresses[frame], MARIO_FRAME_BYTES);
        }
        return;
    }

    for (frame = 0; frame < MARIO_FRAME_STORE_COUNT; ++frame) {
        volatile u16 *pixels = (volatile u16 *)frame_addresses[frame];
        u32 y;

        for (y = 0; y < MARIO_FRAME_HEIGHT; ++y) {
            u32 x;
            for (x = 0; x < MARIO_FRAME_WIDTH; ++x) {
                pixels[y * MARIO_FRAME_WIDTH + x] = color_bars[x / 160U];
            }
        }
        Xil_DCacheFlushRange(frame_addresses[frame], MARIO_FRAME_BYTES);
    }
}

static int initialize_vdma(XAxiVdma *vdma)
{
    XAxiVdma_Config *config;
    int status;

    if (vdma == NULL) {
        return -1;
    }

    config = XAxiVdma_LookupConfig(MARIO_AXI_VDMA_DEVICE_ID);
    if (config == NULL) {
        return -2;
    }
    status = XAxiVdma_CfgInitialize(vdma, config, config->BaseAddress);
    if (status != XST_SUCCESS) {
        return -3;
    }

    initialize_frame_addresses();
    return 0;
}

static void clear_frame_stores(void)
{
    u32 index;

    for (index = 0; index < MARIO_FRAME_STORE_COUNT; ++index) {
        memset((void *)frame_addresses[index], 0, MARIO_FRAME_BYTES);
        Xil_DCacheFlushRange(frame_addresses[index], MARIO_FRAME_BYTES);
    }
}

static void fill_setup(XAxiVdma_DmaSetup *setup, u32 frame_delay)
{
    memset(setup, 0, sizeof(*setup));
    setup->VertSizeInput = MARIO_FRAME_HEIGHT;
    setup->HoriSizeInput = MARIO_FRAME_STRIDE;
    setup->Stride = MARIO_FRAME_STRIDE;
    setup->FrameDelay = frame_delay;
    setup->EnableCircularBuf = 1;
    setup->EnableSync = 1;
    setup->PointNum = 0;
    setup->EnableFrameCounter = 0;
    setup->FixedFrameStoreAddr = 0;
}

int mario_framebuffer_init_mm2s(
    XAxiVdma *vdma,
    mario_framebuffer_pattern_t pattern
)
{
    XAxiVdma_DmaSetup read_setup;
    int status;

    if ((pattern != MARIO_FRAMEBUFFER_BLACK) &&
        (pattern != MARIO_FRAMEBUFFER_COLOR_BARS)) {
        return -10;
    }

    status = initialize_vdma(vdma);
    if (status != 0) {
        return status;
    }

    fill_frame_stores(pattern);
    fill_setup(&read_setup, 0U);
    read_setup.EnableSync = 0;

    status = XAxiVdma_DmaConfig(vdma, XAXIVDMA_READ, &read_setup);
    if (status != XST_SUCCESS) return -4;
    status = XAxiVdma_DmaSetBufferAddr(
        vdma, XAXIVDMA_READ, frame_addresses);
    if (status != XST_SUCCESS) return -5;
    status = XAxiVdma_DmaStart(vdma, XAXIVDMA_READ);
    if (status != XST_SUCCESS) return -6;

    return 0;
}

int mario_framebuffer_init(XAxiVdma *vdma)
{
    XAxiVdma_DmaSetup write_setup;
    XAxiVdma_DmaSetup read_setup;
    int status;

    status = initialize_vdma(vdma);
    if (status != 0) {
        return status;
    }
    clear_frame_stores();

    fill_setup(&write_setup, 0U);
    fill_setup(&read_setup, 1U);

    status = XAxiVdma_DmaConfig(vdma, XAXIVDMA_WRITE, &write_setup);
    if (status != XST_SUCCESS) return -4;
    status = XAxiVdma_DmaSetBufferAddr(
        vdma, XAXIVDMA_WRITE, frame_addresses);
    if (status != XST_SUCCESS) return -5;

    status = XAxiVdma_DmaConfig(vdma, XAXIVDMA_READ, &read_setup);
    if (status != XST_SUCCESS) return -6;
    status = XAxiVdma_DmaSetBufferAddr(
        vdma, XAXIVDMA_READ, frame_addresses);
    if (status != XST_SUCCESS) return -7;

    // The read channel initially displays cleared frame stores. The renderer
    // remains disabled until all SD assets have been uploaded.
    status = XAxiVdma_DmaStart(vdma, XAXIVDMA_READ);
    if (status != XST_SUCCESS) return -8;
    status = XAxiVdma_DmaStart(vdma, XAXIVDMA_WRITE);
    if (status != XST_SUCCESS) return -9;
    return 0;
}
