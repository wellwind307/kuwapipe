// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2025.2 (64-bit)
// Tool Version Limit: 2025.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
#ifndef __linux__

#include "xstatus.h"
#ifdef SDT
#include "xparameters.h"
#endif
#include "xmedian_blur_color.h"

extern XMedian_blur_color_Config XMedian_blur_color_ConfigTable[];

#ifdef SDT
XMedian_blur_color_Config *XMedian_blur_color_LookupConfig(UINTPTR BaseAddress) {
	XMedian_blur_color_Config *ConfigPtr = NULL;

	int Index;

	for (Index = (u32)0x0; XMedian_blur_color_ConfigTable[Index].Name != NULL; Index++) {
		if (!BaseAddress || XMedian_blur_color_ConfigTable[Index].Control_BaseAddress == BaseAddress) {
			ConfigPtr = &XMedian_blur_color_ConfigTable[Index];
			break;
		}
	}

	return ConfigPtr;
}

int XMedian_blur_color_Initialize(XMedian_blur_color *InstancePtr, UINTPTR BaseAddress) {
	XMedian_blur_color_Config *ConfigPtr;

	Xil_AssertNonvoid(InstancePtr != NULL);

	ConfigPtr = XMedian_blur_color_LookupConfig(BaseAddress);
	if (ConfigPtr == NULL) {
		InstancePtr->IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	return XMedian_blur_color_CfgInitialize(InstancePtr, ConfigPtr);
}
#else
XMedian_blur_color_Config *XMedian_blur_color_LookupConfig(u16 DeviceId) {
	XMedian_blur_color_Config *ConfigPtr = NULL;

	int Index;

	for (Index = 0; Index < XPAR_XMEDIAN_BLUR_COLOR_NUM_INSTANCES; Index++) {
		if (XMedian_blur_color_ConfigTable[Index].DeviceId == DeviceId) {
			ConfigPtr = &XMedian_blur_color_ConfigTable[Index];
			break;
		}
	}

	return ConfigPtr;
}

int XMedian_blur_color_Initialize(XMedian_blur_color *InstancePtr, u16 DeviceId) {
	XMedian_blur_color_Config *ConfigPtr;

	Xil_AssertNonvoid(InstancePtr != NULL);

	ConfigPtr = XMedian_blur_color_LookupConfig(DeviceId);
	if (ConfigPtr == NULL) {
		InstancePtr->IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	return XMedian_blur_color_CfgInitialize(InstancePtr, ConfigPtr);
}
#endif

#endif

