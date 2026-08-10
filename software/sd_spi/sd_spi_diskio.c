/* FatFs disk I/O bridge for the read-only SD SPI driver. */
#include "sd_spi_diskio.h"

#include "diskio.h"

static sd_spi_t *bound_sd;

void sd_spi_diskio_bind(sd_spi_t *sd)
{
    bound_sd = sd;
}

DSTATUS disk_status(BYTE pdrv)
{
    if (pdrv != 0U || bound_sd == NULL || !bound_sd->initialized) {
        return STA_NOINIT;
    }
    return 0U;
}

DSTATUS disk_initialize(BYTE pdrv)
{
    /* sd_spi_init() is called explicitly by the Vitis application. */
    return disk_status(pdrv);
}

DRESULT disk_read(BYTE pdrv, BYTE *buff, LBA_t sector, UINT count)
{
    if (pdrv != 0U || buff == NULL || count == 0U) {
        return RES_PARERR;
    }
    if (disk_status(pdrv) & STA_NOINIT) {
        return RES_NOTRDY;
    }
    return sd_spi_read_blocks(bound_sd, (u32)sector, buff, (u32)count) ==
                   SD_SPI_OK
               ? RES_OK
               : RES_ERROR;
}

DRESULT disk_write(BYTE pdrv, const BYTE *buff, LBA_t sector, UINT count)
{
    (void)pdrv;
    (void)buff;
    (void)sector;
    (void)count;
    return RES_WRPRT;
}

DRESULT disk_ioctl(BYTE pdrv, BYTE command, void *buffer)
{
    if (pdrv != 0U) {
        return RES_PARERR;
    }
    if (disk_status(pdrv) & STA_NOINIT) {
        return RES_NOTRDY;
    }

    switch (command) {
    case CTRL_SYNC:
        return RES_OK;
    case GET_SECTOR_SIZE:
        *(WORD *)buffer = 512U;
        return RES_OK;
    case GET_BLOCK_SIZE:
        *(DWORD *)buffer = 1U;
        return RES_OK;
    case GET_SECTOR_COUNT:
        /* FatFs does not need this to read an already-formatted FAT volume. */
        return RES_PARERR;
    default:
        return RES_PARERR;
    }
}

DWORD get_fattime(void)
{
    /* Read-only media access does not need a real-time clock. */
    return 0U;
}
