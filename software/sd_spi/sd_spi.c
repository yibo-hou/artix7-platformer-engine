#include "sd_spi.h"

#include <string.h>

#include "xstatus.h"

#define SD_BLOCK_SIZE                 512U
#define SD_DUMMY_BYTE                 0xFFU
#define SD_START_BLOCK_TOKEN           0xFEU
#define SD_R1_IDLE                     0x01U
#define SD_R1_ILLEGAL_COMMAND          0x04U
#define SD_RESPONSE_TIMEOUT            16U
#define SD_READY_TIMEOUT                10000U
#define SD_TOKEN_TIMEOUT                100000U
#define SD_TOKEN_PADDING                1024U

#define SD_CMD0_GO_IDLE                0U
#define SD_CMD8_SEND_IF_COND            8U
#define SD_CMD16_SET_BLOCKLEN           16U
#define SD_CMD17_READ_SINGLE_BLOCK      17U
#define SD_CMD55_APP_CMD                55U
#define SD_ACMD41_SD_SEND_OP_COND       41U
#define SD_CMD58_READ_OCR               58U

static sd_spi_result_t spi_transfer(
    sd_spi_t *sd,
    const u8 *tx,
    u8 *rx,
    u32 length
)
{
    if (XSpi_Transfer(&sd->spi, (u8 *)tx, rx, length) != XST_SUCCESS) {
        return SD_SPI_ERR_SPI;
    }
    return SD_SPI_OK;
}

static sd_spi_result_t sd_send_command(
    sd_spi_t *sd,
    u8 command,
    u32 argument,
    u8 crc,
    u8 *r1,
    u8 *extra,
    u32 extra_length
)
{
    u32 total_length = 6U + SD_RESPONSE_TIMEOUT + extra_length;
    u32 count;
    sd_spi_result_t result;

    memset(sd->scratch_tx, SD_DUMMY_BYTE, total_length);
    sd->scratch_tx[0] = 0x40U | command;
    sd->scratch_tx[1] = (u8)(argument >> 24);
    sd->scratch_tx[2] = (u8)(argument >> 16);
    sd->scratch_tx[3] = (u8)(argument >> 8);
    sd->scratch_tx[4] = (u8)argument;
    sd->scratch_tx[5] = crc;

    /* XSpi_Transfer deasserts CS at the end of every call. Keep the command,
     * response wait and optional R3/R7 bytes in one transfer so CS never
     * rises in the middle of an SD transaction. */
    XSpi_SetSlaveSelect(&sd->spi, 1U);
    result = spi_transfer(
        sd, sd->scratch_tx, sd->scratch_rx, total_length
    );
    XSpi_SetSlaveSelect(&sd->spi, 0U);
    if (result != SD_SPI_OK) {
        return result;
    }

    for (count = 0; count < SD_RESPONSE_TIMEOUT; ++count) {
        u8 response = sd->scratch_rx[6U + count];
        if ((response & 0x80U) == 0U) {
            *r1 = response;
            if (extra != NULL && extra_length != 0U) {
                memcpy(extra, &sd->scratch_rx[7U + count], extra_length);
            }
            return SD_SPI_OK;
        }
    }

    return SD_SPI_ERR_TIMEOUT;
}

static sd_spi_result_t sd_command_r1(
    sd_spi_t *sd,
    u8 command,
    u32 argument,
    u8 crc,
    u8 *r1
)
{
    return sd_send_command(sd, command, argument, crc, r1, NULL, 0U);
}

static u32 sd_command_address(const sd_spi_t *sd, u32 lba)
{
    return (sd->card_type == SD_SPI_CARD_SDHC) ? lba : lba * SD_BLOCK_SIZE;
}

static sd_spi_result_t sd_read_single_block(sd_spi_t *sd, u32 lba, u8 *dst)
{
    const u32 total_length = 6U + SD_RESPONSE_TIMEOUT +
                             SD_TOKEN_PADDING + SD_BLOCK_SIZE + 2U;
    u8 r1;
    u8 token;
    u32 count;
    u32 response_index = 0U;
    u32 token_index = 0U;
    sd_spi_result_t result;

    memset(sd->scratch_tx, SD_DUMMY_BYTE, total_length);
    sd->scratch_tx[0] = 0x40U | SD_CMD17_READ_SINGLE_BLOCK;
    sd->scratch_tx[1] = (u8)(sd_command_address(sd, lba) >> 24);
    sd->scratch_tx[2] = (u8)(sd_command_address(sd, lba) >> 16);
    sd->scratch_tx[3] = (u8)(sd_command_address(sd, lba) >> 8);
    sd->scratch_tx[4] = (u8)sd_command_address(sd, lba);
    sd->scratch_tx[5] = 0x01U;

    XSpi_SetSlaveSelect(&sd->spi, 1U);
    result = spi_transfer(
        sd, sd->scratch_tx, sd->scratch_rx, total_length
    );
    XSpi_SetSlaveSelect(&sd->spi, 0U);
    if (result != SD_SPI_OK) {
        return result;
    }

    for (count = 0U; count < SD_RESPONSE_TIMEOUT; ++count) {
        r1 = sd->scratch_rx[6U + count];
        if ((r1 & 0x80U) == 0U) {
            response_index = 6U + count;
            break;
        }
    }
    if (count == SD_RESPONSE_TIMEOUT) {
        return SD_SPI_ERR_TIMEOUT;
    }
    if (r1 != 0U) {
        return SD_SPI_ERR_RESPONSE;
    }

    for (count = response_index + 1U;
         count < total_length - SD_BLOCK_SIZE - 2U;
         ++count) {
        token = sd->scratch_rx[count];
        if (token == SD_START_BLOCK_TOKEN) {
            token_index = count;
            break;
        }
        if (token != SD_DUMMY_BYTE) {
            return SD_SPI_ERR_TOKEN;
        }
    }
    if (token_index == 0U) {
        return SD_SPI_ERR_TIMEOUT;
    }

    memcpy(dst, &sd->scratch_rx[token_index + 1U], SD_BLOCK_SIZE);
    return SD_SPI_OK;
}

sd_spi_result_t sd_spi_init(sd_spi_t *sd, UINTPTR spi_id_or_base)
{
    XSpi_Config *config;
    u32 attempt;
    u8 r1;
    u8 response[4];
    sd_spi_result_t result;

    if (sd == NULL) {
        return SD_SPI_ERR_ARGUMENT;
    }

    memset(sd, 0, sizeof(*sd));
    memset(sd->scratch_tx, SD_DUMMY_BYTE, sizeof(sd->scratch_tx));

    config = XSpi_LookupConfig(spi_id_or_base);
    if (config == NULL) {
        return SD_SPI_ERR_ARGUMENT;
    }
    if (XSpi_CfgInitialize(&sd->spi, config, config->BaseAddress) != XST_SUCCESS) {
        return SD_SPI_ERR_SPI;
    }
    if (XSpi_SetOptions(&sd->spi, XSP_MASTER_OPTION |
                                  XSP_MANUAL_SSELECT_OPTION) != XST_SUCCESS) {
        return SD_SPI_ERR_SPI;
    }
    XSpi_Start(&sd->spi);
    /* XSpi_Start enables the core's global interrupt bit. This design does
     * not connect an SPI interrupt handler, so explicitly select the polling
     * path used by XSpi_Transfer. Otherwise it returns before the FIFO has
     * shifted any bytes and no CS/SCK activity reaches the card. */
    XSpi_IntrGlobalDisable(&sd->spi);
    XSpi_SetSlaveSelect(&sd->spi, 0U);

    /* At least 74 clocks with CS high before CMD0. */
    result = spi_transfer(sd, sd->scratch_tx, sd->scratch_rx, 10U);
    if (result != SD_SPI_OK) {
        return result;
    }

    for (attempt = 0; attempt < 20U; ++attempt) {
        result = sd_command_r1(sd, SD_CMD0_GO_IDLE, 0U, 0x95U, &r1);
        if (result == SD_SPI_OK && r1 == SD_R1_IDLE) {
            break;
        }
    }
    if (attempt == 20U) {
        return SD_SPI_ERR_NOT_READY;
    }

    result = sd_send_command(
        sd, SD_CMD8_SEND_IF_COND, 0x1AAU, 0x87U,
        &r1, response, sizeof(response)
    );
    if (result != SD_SPI_OK) {
        return result;
    }
    if (r1 == SD_R1_IDLE) {
        if (response[2] != 0x01U || response[3] != 0xAAU) {
            return SD_SPI_ERR_RESPONSE;
        }
        sd->card_type = SD_SPI_CARD_SDSC_V2;
    } else if ((r1 & SD_R1_ILLEGAL_COMMAND) != 0U) {
        sd->card_type = SD_SPI_CARD_SDSC_V1;
    } else {
        return SD_SPI_ERR_RESPONSE;
    }

    for (attempt = 0; attempt < 2000U; ++attempt) {
        result = sd_command_r1(sd, SD_CMD55_APP_CMD, 0U, 0x01U, &r1);
        if (result != SD_SPI_OK || (r1 != SD_R1_IDLE && r1 != 0U)) {
            return SD_SPI_ERR_RESPONSE;
        }
        result = sd_command_r1(
            sd,
            SD_ACMD41_SD_SEND_OP_COND,
            (sd->card_type == SD_SPI_CARD_SDSC_V2) ? 0x40000000U : 0U,
            0x01U,
            &r1
        );
        if (result != SD_SPI_OK) {
            return result;
        }
        if (r1 == 0U) {
            break;
        }
    }
    if (attempt == 2000U) {
        return SD_SPI_ERR_NOT_READY;
    }

    result = sd_send_command(
        sd, SD_CMD58_READ_OCR, 0U, 0x01U,
        &r1, response, sizeof(response)
    );
    if (result != SD_SPI_OK || r1 != 0U) {
        return SD_SPI_ERR_RESPONSE;
    }
    if (sd->card_type == SD_SPI_CARD_SDSC_V2 && (response[0] & 0x40U) != 0U) {
        sd->card_type = SD_SPI_CARD_SDHC;
    }

    if (sd->card_type != SD_SPI_CARD_SDHC) {
        result = sd_command_r1(sd, SD_CMD16_SET_BLOCKLEN, SD_BLOCK_SIZE, 0x01U, &r1);
        if (result != SD_SPI_OK || r1 != 0U) {
            return SD_SPI_ERR_RESPONSE;
        }
    }

    sd->initialized = 1U;
    return SD_SPI_OK;
}

sd_spi_result_t sd_spi_read_blocks(
    sd_spi_t *sd,
    u32 lba,
    u8 *dst,
    u32 block_count
)
{
    u32 block;
    sd_spi_result_t result;

    if (sd == NULL || dst == NULL || block_count == 0U || !sd->initialized) {
        return SD_SPI_ERR_ARGUMENT;
    }

    for (block = 0; block < block_count; ++block) {
        result = sd_read_single_block(sd, lba + block, dst + block * SD_BLOCK_SIZE);
        if (result != SD_SPI_OK) {
            return result;
        }
    }
    return SD_SPI_OK;
}

sd_spi_result_t sd_spi_read_bytes(
    sd_spi_t *sd,
    u32 byte_offset,
    u8 *dst,
    u32 byte_count
)
{
    u8 block[SD_BLOCK_SIZE];
    u32 lba;
    u32 block_offset;
    u32 copy_count;
    sd_spi_result_t result;

    if (sd == NULL || dst == NULL || !sd->initialized) {
        return SD_SPI_ERR_ARGUMENT;
    }

    while (byte_count != 0U) {
        lba = byte_offset / SD_BLOCK_SIZE;
        block_offset = byte_offset % SD_BLOCK_SIZE;
        copy_count = SD_BLOCK_SIZE - block_offset;
        if (copy_count > byte_count) {
            copy_count = byte_count;
        }

        result = sd_spi_read_blocks(sd, lba, block, 1U);
        if (result != SD_SPI_OK) {
            return result;
        }
        memcpy(dst, &block[block_offset], copy_count);
        dst += copy_count;
        byte_offset += copy_count;
        byte_count -= copy_count;
    }
    return SD_SPI_OK;
}
