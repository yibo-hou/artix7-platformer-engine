#include "platform.h"
#include "sleep.h"
#include "xaxivdma.h"
#include "xil_printf.h"

#include "../common/mario_framebuffer.h"

static XAxiVdma axi_vdma;

int main(void)
{
    int status;

    init_platform();
    xil_printf("Framebuffer bring-up: start\r\n");
    xil_printf("Filling RGB565 color bars and starting VDMA MM2S only\r\n");

    status = mario_framebuffer_init_mm2s(
        &axi_vdma,
        MARIO_FRAMEBUFFER_COLOR_BARS
    );
    if (status != 0) {
        xil_printf("VDMA MM2S setup failed: %d\r\n", status);
        for (;;) {
        }
    }

    xil_printf("VDMA MM2S running\r\n");
    for (;;) {
        int errors = XAxiVdma_GetDmaChannelErrors(
            &axi_vdma,
            XAXIVDMA_READ
        );
        if (errors != 0) {
            xil_printf("VDMA MM2S errors: 0x%08x\r\n", (unsigned int)errors);
        }
        sleep(1);
    }
}
