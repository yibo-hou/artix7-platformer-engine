#ifndef TEST_XAXIDMA_H
#define TEST_XAXIDMA_H
#include "xil_types.h"
typedef struct { int unused; } XAxiDma;
typedef struct { int HasSg; } XAxiDma_Config;
#define XAXIDMA_DMA_TO_DEVICE 0
#define XAXIDMA_IRQ_ALL_MASK 0xFFFFFFFFU
XAxiDma_Config *XAxiDma_LookupConfig(u16 device_id);
int XAxiDma_CfgInitialize(XAxiDma *dma, XAxiDma_Config *config);
int XAxiDma_HasSg(XAxiDma *dma);
int XAxiDma_SimpleTransfer(
    XAxiDma *dma, UINTPTR address, u32 length, int direction);
int XAxiDma_Busy(XAxiDma *dma, int direction);
void XAxiDma_IntrDisable(XAxiDma *dma, u32 mask, int direction);
#endif
