// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2025.2 (64-bit)
// Tool Version Limit: 2025.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
#ifndef XMEDIAN_BLUR_COLOR_H
#define XMEDIAN_BLUR_COLOR_H

#ifdef __cplusplus
extern "C" {
#endif

/***************************** Include Files *********************************/
#ifndef __linux__
#include "xil_types.h"
#include "xil_assert.h"
#include "xstatus.h"
#include "xil_io.h"
#else
#include <stdint.h>
#include <assert.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stddef.h>
#endif
#include "xmedian_blur_color_hw.h"

/**************************** Type Definitions ******************************/
#ifdef __linux__
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
#else
typedef struct {
#ifdef SDT
    char *Name;
#else
    u16 DeviceId;
#endif
    u64 Control_BaseAddress;
} XMedian_blur_color_Config;
#endif

typedef struct {
    u64 Control_BaseAddress;
    u32 IsReady;
} XMedian_blur_color;

typedef u32 word_type;

/***************** Macros (Inline Functions) Definitions *********************/
#ifndef __linux__
#define XMedian_blur_color_WriteReg(BaseAddress, RegOffset, Data) \
    Xil_Out32((BaseAddress) + (RegOffset), (u32)(Data))
#define XMedian_blur_color_ReadReg(BaseAddress, RegOffset) \
    Xil_In32((BaseAddress) + (RegOffset))
#else
#define XMedian_blur_color_WriteReg(BaseAddress, RegOffset, Data) \
    *(volatile u32*)((BaseAddress) + (RegOffset)) = (u32)(Data)
#define XMedian_blur_color_ReadReg(BaseAddress, RegOffset) \
    *(volatile u32*)((BaseAddress) + (RegOffset))

#define Xil_AssertVoid(expr)    assert(expr)
#define Xil_AssertNonvoid(expr) assert(expr)

#define XST_SUCCESS             0
#define XST_DEVICE_NOT_FOUND    2
#define XST_OPEN_DEVICE_FAILED  3
#define XIL_COMPONENT_IS_READY  1
#endif

/************************** Function Prototypes *****************************/
#ifndef __linux__
#ifdef SDT
int XMedian_blur_color_Initialize(XMedian_blur_color *InstancePtr, UINTPTR BaseAddress);
XMedian_blur_color_Config* XMedian_blur_color_LookupConfig(UINTPTR BaseAddress);
#else
int XMedian_blur_color_Initialize(XMedian_blur_color *InstancePtr, u16 DeviceId);
XMedian_blur_color_Config* XMedian_blur_color_LookupConfig(u16 DeviceId);
#endif
int XMedian_blur_color_CfgInitialize(XMedian_blur_color *InstancePtr, XMedian_blur_color_Config *ConfigPtr);
#else
int XMedian_blur_color_Initialize(XMedian_blur_color *InstancePtr, const char* InstanceName);
int XMedian_blur_color_Release(XMedian_blur_color *InstancePtr);
#endif


void XMedian_blur_color_Set_rows(XMedian_blur_color *InstancePtr, u32 Data);
u32 XMedian_blur_color_Get_rows(XMedian_blur_color *InstancePtr);
void XMedian_blur_color_Set_cols(XMedian_blur_color *InstancePtr, u32 Data);
u32 XMedian_blur_color_Get_cols(XMedian_blur_color *InstancePtr);

#ifdef __cplusplus
}
#endif

#endif
