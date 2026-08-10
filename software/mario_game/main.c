#include "ff.h"
#include "platform.h"
#include "sleep.h"
#include "xaxidma.h"
#include "xil_printf.h"
#include "xstatus.h"
#include "xuartlite.h"

#include "mario_assets.h"
#include "mario_game.h"
#include "mario_framebuffer.h"
#include "platform_config.h"
#include "sd_spi.h"
#include "sd_spi_diskio.h"
#include "sprite_engine_regs.h"

static XAxiDma axi_dma;
static XAxiVdma axi_vdma;
static XUartLite uart;
static sd_spi_t sd_card;
static FATFS fatfs;
static mario_assets_t assets;
static mario_game_t game;

static int initialize_dma(void)
{
    XAxiDma_Config *config = XAxiDma_LookupConfig(MARIO_AXI_DMA_DEVICE_ID);
    if (config == NULL) {
        return -1;
    }
    if (XAxiDma_CfgInitialize(&axi_dma, config) != XST_SUCCESS) {
        return -2;
    }
    if (XAxiDma_HasSg(&axi_dma)) {
        return -3;
    }
    XAxiDma_IntrDisable(
        &axi_dma,
        XAXIDMA_IRQ_ALL_MASK,
        XAXIDMA_DMA_TO_DEVICE
    );
    return 0;
}

static int initialize_uart(void)
{
    XUartLite_Config *config =
        XUartLite_LookupConfig(MARIO_UART_DEVICE_ID);
    if (config == NULL) {
        return -1;
    }
    if (XUartLite_CfgInitialize(
            &uart, config, config->RegBaseAddr) != XST_SUCCESS) {
        return -2;
    }
    XUartLite_ResetFifos(&uart);
    return 0;
}

static u8 receive_keyboard_state(u8 previous)
{
    u8 byte;
    unsigned int received;

    do {
        received = XUartLite_Recv(&uart, &byte, 1U);
        if (received == 1U) {
            previous = byte;
        }
    } while (received == 1U);
    return previous;
}

int main(void)
{
    FRESULT fat_result;
    u8 input_state = 0U;
    int result;

    init_platform();
    xil_printf("Copper Hills: boot\r\n");

    result = initialize_dma();
    if (result != 0) {
        xil_printf("AXI DMA init failed: %d\r\n", result);
        goto failed;
    }
    result = initialize_uart();
    if (result != 0) {
        xil_printf("UART init failed: %d\r\n", result);
        goto failed;
    }
    result = mario_framebuffer_init(&axi_vdma);
    if (result != 0) {
        xil_printf("AXI VDMA init failed: %d\r\n", result);
        goto failed;
    }
    result = sd_spi_init(&sd_card, MARIO_SD_SPI_DEVICE_ID);
    if (result != SD_SPI_OK) {
        xil_printf("SD SPI init failed: %d\r\n", result);
        goto failed;
    }

    sd_spi_diskio_bind(&sd_card);
    fat_result = f_mount(&fatfs, "0:", 1);
    if (fat_result != FR_OK) {
        xil_printf("FAT32 mount failed: %d\r\n", (int)fat_result);
        goto failed;
    }

    result = mario_assets_load_from_sd(&assets);
    if (result != 0) {
        xil_printf("Asset load failed: %d\r\n", result);
        goto failed;
    }
    result = mario_assets_upload_initial(&assets, &axi_dma);
    if (result != 0) {
        xil_printf("Initial asset DMA failed: %d\r\n", result);
        goto failed;
    }
    result = mario_game_init(&game, &assets, &axi_dma);
    if (result != 0) {
        xil_printf("Game init failed: %d\r\n", result);
        goto failed;
    }
    sprite_set_render_enable(MARIO_SPRITE_CTRL_BASEADDR, 1U);

    xil_printf("Copper Hills: running\r\n");
    for (;;) {
        input_state = receive_keyboard_state(input_state);
        result = mario_game_update(&game, input_state);
        if (result != 0) {
            xil_printf("Game update failed: %d\r\n", result);
            goto failed;
        }
        usleep(MARIO_FRAME_US);
    }

failed:
    xil_printf("Copper Hills halted\r\n");
    for (;;) {
    }
}
