#ifndef XILFFS_CONFIG_H
#define XILFFS_CONFIG_H

/* Minimal read-only FatFs configuration for the custom AXI SPI SD driver. */
#define FILE_SYSTEM_INTERFACE_SD
#define FILE_SYSTEM_READ_ONLY
#define FILE_SYSTEM_NUM_LOGIC_VOL      1U
#define FILE_SYSTEM_MAX_SECTOR_SIZE    512U
#define FILE_SYSTEM_USE_LFN            0
#define FILE_SYSTEM_SET_FS_RPATH       0

#endif
