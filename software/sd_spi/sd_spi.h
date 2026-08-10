#ifndef SD_SPI_H
#define SD_SPI_H

#include "xil_types.h"
#include "xspi.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    SD_SPI_OK = 0,
    SD_SPI_ERR_ARGUMENT = -1,
    SD_SPI_ERR_SPI = -2,
    SD_SPI_ERR_TIMEOUT = -3,
    SD_SPI_ERR_RESPONSE = -4,
    SD_SPI_ERR_TOKEN = -5,
    SD_SPI_ERR_NOT_READY = -6
} sd_spi_result_t;

typedef enum {
    SD_SPI_CARD_UNKNOWN = 0,
    SD_SPI_CARD_SDSC_V1,
    SD_SPI_CARD_SDSC_V2,
    SD_SPI_CARD_SDHC
} sd_spi_card_type_t;

typedef struct {
    XSpi spi;
    sd_spi_card_type_t card_type;
    u8 initialized;
    u8 scratch_tx[1600];
    u8 scratch_rx[1600];
} sd_spi_t;

/** Configure AXI Quad SPI and initialize a card in SPI mode. */
sd_spi_result_t sd_spi_init(sd_spi_t *sd, UINTPTR spi_id_or_base);

/** Read one or more 512-byte SD logical blocks into dst. */
sd_spi_result_t sd_spi_read_blocks(
    sd_spi_t *sd,
    u32 lba,
    u8 *dst,
    u32 block_count
);

/** Read a byte range by reading and trimming the required SD blocks. */
sd_spi_result_t sd_spi_read_bytes(
    sd_spi_t *sd,
    u32 byte_offset,
    u8 *dst,
    u32 byte_count
);

#ifdef __cplusplus
}
#endif

#endif
