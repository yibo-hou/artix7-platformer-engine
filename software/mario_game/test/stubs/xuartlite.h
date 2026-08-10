#ifndef TEST_XUARTLITE_H
#define TEST_XUARTLITE_H
#include "xil_types.h"
typedef struct { int unused; } XUartLite;
typedef struct { UINTPTR RegBaseAddr; } XUartLite_Config;
XUartLite_Config *XUartLite_LookupConfig(u16 device_id);
int XUartLite_CfgInitialize(
    XUartLite *uart,
    XUartLite_Config *config,
    UINTPTR effective_address);
void XUartLite_ResetFifos(XUartLite *uart);
unsigned int XUartLite_Recv(XUartLite *uart, u8 *data, unsigned int count);
#endif
