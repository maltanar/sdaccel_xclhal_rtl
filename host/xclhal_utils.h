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

#ifndef _UTILS_H_
#include <stdint.h>

// A very thin wrapper around XCL HAL calls for low-level device access

// init (load bitstream/xclbin) and deinit functions
void init(const char * xclbin);
void deinit();

// 32-bit user logic AXI-lite register reads and writes
const uint32_t readReg32(const uint64_t reg_offset);
void writeReg32(const uint64_t reg_offset, const uint32_t value);

// 64-bit user logic AXI-lite register reads and writes
// implemented as two consecutive 32-bit reads/writes
const uint64_t readReg64(const uint64_t reg_offset);
void writeReg64(const uint64_t reg_offset, const uint64_t value);

// (de)allocate/copy buffers between host memory and device memory
uint64_t allocDRAM(const size_t bytes);
void freeDRAM(const uint64_t buffer);
void readDRAM(const uint64_t dram_offset, void * buf, const size_t nbytes);
void writeDRAM(const uint64_t dram_offset, const void * buf, const size_t nbytes);

#define _UTILS_H_
#endif // _UTILS_H_
