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
#include <iostream>
#include <string.h>
#include "xclhal_utils.h"

using namespace std;

int main(int argc, char** argv)
{
	if(argc != 2) {
		std::cout << "Usage: " << argv[0] << " <path_to_xclbin>" << endl;
		return -1;
	}
	init(argv[1]);
		// copied here for convenience:
    // control
    // 0x00 : Control signals
    //        bit 0  - ap_start (Read/Write/COH)
    //        bit 1  - ap_done (Read/COR)
    //        bit 2  - ap_idle (Read)
    //        bit 3  - ap_ready (Read)
    //        bit 7  - auto_restart (Read/Write)
    //        others - reserved
    // 0x04 : Global Interrupt Enable Register
    //        bit 0  - Global Interrupt Enable (Read/Write)
    //        others - reserved
    // 0x08 : IP Interrupt Enable Register (Read/Write)
    //        bit 0  - Channel 0 (ap_done)
    //        bit 1  - Channel 1 (ap_ready)
    //        others - reserved
    // 0x0c : IP Interrupt Status Register (Read/TOW)
    //        bit 0  - Channel 0 (ap_done)
    //        bit 1  - Channel 1 (ap_ready)
    //        others - reserved
    // 0x10 : Data signal of src_V
    //        bit 31~0 - src_V[31:0] (Read/Write)
    // 0x14 : Data signal of src_V
    //        bit 31~0 - src_V[63:32] (Read/Write)
    // 0x18 : reserved
    // 0x1c : Data signal of dst_V
    //        bit 31~0 - dst_V[31:0] (Read/Write)
  // 0x20 : Data signal of dst_V
  //        bit 31~0 - dst_V[63:32] (Read/Write)
  // 0x24 : reserved
  // 0x28 : Data signal of nwords
  //        bit 31~0 - nwords[31:0] (Read/Write)
  // 0x2c : reserved
  // (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)
  // read and print the accel status/control register, normally 4 (1 << 2) when idle
	cout << "Read reg 0 (accel status/control), value = " << readReg32(0x0) << endl;
	// prepare buffers on the host side and initialize with a known pattern
	const int dram_elems = 1024;
	const int dram_nbytes = dram_elems * sizeof(unsigned int);
  unsigned int *bufA = new unsigned int[dram_elems];
  unsigned int *bufB = new unsigned int[dram_elems];
  for(int i = 0; i < dram_elems; i++) {
    bufA[i] = i+1;
    bufB[i] = 0;
  }
  // offsets for buffers in device memory
  const uint64_t dram_offs_src = allocDRAM(dram_nbytes);
  const uint64_t dram_offs_dst = allocDRAM(dram_nbytes);
  cout << "Allocated buffers on device mem: src = " << hex << dram_offs_src << " dest = " << dram_offs_dst << endl;
  assert(dram_offs_src != 0xffffffffffffffff);
  assert(dram_offs_dst != 0xffffffffffffffff);
  // copy from host memory into device memory
  writeDRAM(dram_offs_src, bufA, dram_nbytes);
  // validate host->device transfer by reading back and comparing
  readDRAM(dram_offs_src, bufB, dram_nbytes);
  cout << "Host -> device -> host memory copy ";
  if(memcmp(bufA, bufB, dram_nbytes) == 0) {
     cout << "OK";
  } else {
    cout << "failed";
    for(int i = 0; i < dram_elems; i++) {
    	cout << i << ": bufA = " << bufA[i] << " bufB = " << bufB[i] << endl;
  	}
  }
  cout << endl;
  // set up buffer pointers in registers and number of words
  writeReg64(0x10, dram_offs_src);
  writeReg64(0x1c, dram_offs_dst);
  writeReg32(0x28, dram_elems);
  // verify that buffer registers are set up correctly
  assert(readReg64(0x10) == dram_offs_src);
  assert(readReg64(0x1c) == dram_offs_dst);
  assert(readReg32(0x28) == dram_elems);
  // start accel and wait until done
  writeReg32(0x00, 1);
  while(readReg32(0x00) & 0x2 != 0x2);
  // copy the FPGA-copied target buffer into the host and compare
  cout << "Kernel execution done, processed " << dec << readReg32(0x28) << " words" << endl;
  memset(bufB, 0, dram_nbytes);
  readDRAM(dram_offs_dst, bufB, dram_nbytes);
  cout << "Host -> device DDR -> device increment -> device increment -> device DDR -> Host computation ";
  int nerrors = 0;
  for(int i = 0; i < dram_elems; i++) {
     if(bufB[i] != bufA[i]+2) nerrors++;
  }
  if(nerrors == 0) {
     cout << "OK";
  } else {
    cout << "failed";
  }
  cout << endl;
  freeDRAM(dram_offs_src);
  freeDRAM(dram_offs_dst);
  deinit();
  delete [] bufA;
  delete [] bufB;
	return 0;
}

