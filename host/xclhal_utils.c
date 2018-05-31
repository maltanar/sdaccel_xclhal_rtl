# /*******************************************************************************
# Copyright (c) 2018, Xilinx, Inc.
# All rights reserved.
# Author: Yaman Umuroglu
# 
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 
# 
# 3. Neither the name of the copyright holder nor the names of its contributors
# may be used to endorse or promote products derived from this software
# without specific prior written permission.
# 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY 
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# *******************************************************************************/

#include <assert.h>
#include <stdio.h>
#include <xclhal2.h>
#include "xclhal_utils.h"

// A very thin wrapper around XCL HAL calls for low-level device access
// Quickstart:
// ==============================================================================
// 1. Call init(path_to_xclbin)
// 2. Use readReg*/writeReg* to r/w AXI lite regs, *= 32 or 64 for reg bitwidth.
// 3. Use allocDRAM to allocate DRAM buffers on-device.
// 4. Use writeDRAM to copy from host to device DRAM buffers.
// 5. Use readDRAM to copy from device to host DRAM buffers.
// 6. Call freeDRAM to free DRAM buffers.
// 7. Call deinit when done.


xclDeviceHandle hDevice;
// base address for user logic AXI lite
const unsigned long long int csr_base = CSR_BASE_ADDR;
const xclAddressSpace csr_addrspace = XCL_ADDR_KERNEL_CTRL; // XCL_ADDR_KERNEL_CTRL
// buffer for reading xclbin into host memory
unsigned char *kernelbinary;

// Helper function to load xclbin file to memory from SDAccel examples
int load_file_to_memory(const char *filename, char **result)
{
    uint size = 0;
    FILE *f = fopen(filename, "rb");
    if (f == NULL) {
        *result = NULL;
        return -1;
    }
    fseek(f, 0, SEEK_END);
    size = ftell(f);
    fseek(f, 0, SEEK_SET);
    // allocate enough memory to hold the xclbin
    *result = (char *)malloc(size+1);
    if (size != fread(*result, sizeof(char), size, f)) {
        free(*result);
        return -2;
    }
    fclose(f);
    (*result)[size] = 0;
    return size;
}

void init(const char * xclbin) {
  // make sure there is at least one device available
  assert(xclProbe() >= 1);
  // open and get exclusive access to the device
  hDevice = xclOpen(0, "xcl.log", XCL_QUIET);
  xclLockDevice(hDevice);
  // set the clock frequency if FCLK_MHZ was defined
#ifdef FCLK_MHZ  
  const unsigned short targetFreqMHz[4] = {FCLK_MHZ, FCLK_MHZ, 0, 0};
  xclReClock2(hDevice, 0, targetFreqMHz);
#endif  
  // load the xclbin contents into memory
	int n_i0 = load_file_to_memory(xclbin, (char **) &kernelbinary);
	assert(n_i0 >= 0);
	// load the xclbin into the device
	xclLoadXclBin(hDevice, (const xclBin*)kernelbinary);
}

void deinit() {
  xclUnlockDevice(hDevice);
  xclClose(hDevice);
  free(kernelbinary);
}

const uint32_t readReg32(const uint64_t reg_offset) {
  uint32_t ret = 0;
  // hw_em does not seem to return correct result from every second call to different address, so just make a dummy call
  size_t nret = xclRead(hDevice, csr_addrspace, csr_base + reg_offset, (void*)&ret, 4);
  nret = xclRead(hDevice, csr_addrspace, csr_base + reg_offset, (void*)&ret, 4);
  assert(nret == 4);
  return ret;
}

void writeReg32(const uint64_t reg_offset, const uint32_t value) {
  size_t nret = xclWrite(hDevice, csr_addrspace, csr_base + reg_offset, (void*)&value, sizeof(unsigned int));
  assert(nret == sizeof(unsigned int));
}

const uint64_t readReg64(const uint64_t reg_offset) {
  uint64_t ret = readReg32(reg_offset);
  ret |= (uint64_t)readReg32(reg_offset + 0x4) << 32;
  return ret;
}

void writeReg64(const uint64_t reg_offset, const uint64_t value) {
  writeReg32(reg_offset, (uint32_t)(value & 0xffffffff));
  writeReg32(reg_offset + 0x4, (uint32_t)((value >> 32) & 0xffffffff));
}

void readDRAM(const uint64_t dram_offset, void * buf, const size_t nbytes) {
  // TODO hw_em in 2017.4 only seems to support legacy APIs for now; should move to Unmgd* variants when it supports them
  //size_t nret = xclCopyBufferDevice2Host(hDevice, buf, dram_offset, nbytes, 0);
  //assert(nret == nbytes);
  int nret = xclUnmgdPread(hDevice, 0, buf, nbytes, dram_offset);
  printf("readDRAM %d bytes from addr %x\n", nbytes, dram_offset); 
  // xclUnmgd* does not seem to return number of read/written bytes; just <0 for errors
  assert(nret >= 0);
}

void writeDRAM(const uint64_t dram_offset, const void * buf, const size_t nbytes) {
  // TODO hw_em in 2017.4 only seems to support legacy APIs for now; should move to Unmgd* variants when it supports them
  //size_t nret = xclCopyBufferHost2Device(hDevice, dram_offset, buf, nblytes, 0);
  //assert(nret == nbytes);
  int nret = xclUnmgdPwrite(hDevice, 0, buf, nbytes, dram_offset);
  printf("writeDRAM %d bytes to addr %x\n", nbytes, dram_offset); 
  // xclUnmgd* does not seem to return number of read/written bytes; just <0 for errors  
  assert(nret >= 0);
}

uint64_t allocDRAM(const size_t bytes) {
	// TODO this is a hal1 call -- should use the hal2 BO functions instead
	// allocate memory from DRAM bank 0
	return xclAllocDeviceBuffer2(hDevice, bytes, XCL_MEM_DEVICE_RAM, XCL_DEVICE_RAM_BANK0);
}

void freeDRAM(const uint64_t buffer) {
	// TODO this is a hal1 call -- should use the hal2 BO functions instead
	xclFreeDeviceBuffer(hDevice, buffer);
}
