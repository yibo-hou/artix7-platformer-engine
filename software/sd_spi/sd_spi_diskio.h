#ifndef SD_SPI_DISKIO_H
#define SD_SPI_DISKIO_H

#include "sd_spi.h"

/* Bind the SD driver instance before calling f_mount(). */
void sd_spi_diskio_bind(sd_spi_t *sd);

#endif
