# Framebuffer MM2S bring-up

This application is intentionally smaller than `mario_game`. It tests only:

```text
MicroBlaze software RGB565 bars
    -> DDR3 frame stores
    -> AXI VDMA MM2S
    -> HDMI asynchronous FIFO
    -> 720p output
```

Add `main.c`, `../common/mario_framebuffer.c`, and the
`../common` include directory to a standalone MicroBlaze application.
The BSP must provide `xaxivdma`, `xil`, and the normal standalone platform
support.

The VDMA read channel is started with frame synchronization disabled. This is
required for the first-stage test because the S2MM channel and its dynamic
genlock source are deliberately inactive.

To display black instead, change `MARIO_FRAMEBUFFER_COLOR_BARS` in `main.c`
to `MARIO_FRAMEBUFFER_BLACK`.
