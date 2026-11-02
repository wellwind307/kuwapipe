// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2025.2 (64-bit)
// Tool Version Limit: 2025.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
/***************************** Include Files *********************************/
#include "xmedian_blur_color.h"

/************************** Function Implementation *************************/
#ifndef __linux__
int XMedian_blur_color_CfgInitialize(XMedian_blur_color *InstancePtr, XMedian_blur_color_Config *ConfigPtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(ConfigPtr != NULL);

    InstancePtr->Control_BaseAddress = ConfigPtr->Control_BaseAddress;
    InstancePtr->IsReady = XIL_COMPONENT_IS_READY;

    return XST_SUCCESS;
}
#endif

void XMedian_blur_color_Set_rows(XMedian_blur_color *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XMedian_blur_color_WriteReg(InstancePtr->Control_BaseAddress, XMEDIAN_BLUR_COLOR_CONTROL_ADDR_ROWS_DATA, Data);
}

u32 XMedian_blur_color_Get_rows(XMedian_blur_color *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XMedian_blur_color_ReadReg(InstancePtr->Control_BaseAddress, XMEDIAN_BLUR_COLOR_CONTROL_ADDR_ROWS_DATA);
    return Data;
}

void XMedian_blur_color_Set_cols(XMedian_blur_color *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XMedian_blur_color_WriteReg(InstancePtr->Control_BaseAddress, XMEDIAN_BLUR_COLOR_CONTROL_ADDR_COLS_DATA, Data);
}

u32 XMedian_blur_color_Get_cols(XMedian_blur_color *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XMedian_blur_color_ReadReg(InstancePtr->Control_BaseAddress, XMEDIAN_BLUR_COLOR_CONTROL_ADDR_COLS_DATA);
    return Data;
}

