#ifndef TEST_FF_H
#define TEST_FF_H
#include "xil_types.h"
typedef struct { int unused; } FIL;
typedef struct { int unused; } FATFS;
typedef int FRESULT;
typedef unsigned int UINT;
#define FR_OK 0
#define FA_READ 1
FRESULT f_open(FIL *file, const char *path, u8 mode);
FRESULT f_read(FIL *file, void *buffer, UINT bytes, UINT *received);
FRESULT f_close(FIL *file);
FRESULT f_mount(FATFS *fatfs, const char *path, u8 mount_now);
#endif
