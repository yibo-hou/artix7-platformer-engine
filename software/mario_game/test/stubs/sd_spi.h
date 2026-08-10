#ifndef TEST_SD_SPI_H
#define TEST_SD_SPI_H
#include "xil_types.h"
typedef struct { int unused; } sd_spi_t;
#define SD_SPI_OK 0
int sd_spi_init(sd_spi_t *card, u16 device_id);
#endif
