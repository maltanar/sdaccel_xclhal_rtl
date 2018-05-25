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
#include "xclhal_utils.h"

using namespace std;

int main(int argc, char** argv)
{
	init("reg2reg.xclbin");
	// copied here from HLS-generated xreg2reg.h for convenience:
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
  // 0x10 : Data signal of ap_return
  //        bit 31~0 - ap_return[31:0] (Read)
  // 0x18 : Data signal of opA_V
  //        bit 31~0 - opA_V[31:0] (Read/Write)
  // 0x1c : reserved
  // 0x20 : Data signal of opB_V
  //        bit 31~0 - opB_V[31:0] (Read/Write)
  // 0x24 : reserved
  // 0x28 : Data signal of mode_V
  //        bit 31~0 - mode_V[31:0] (Read/Write)
  // 0x2c : reserved
  // (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)
  // read and print the accel status/control register, normally 4 (1 << 2) when idle
	cout << "Read reg 0 (accel status/control), value = " << readReg32(0x0) << endl;
	// write 2 to mode register: multiply op
	writeReg32(0x28, 2);
	cout << "ALU mode = " << readReg32(0x28) << endl;
	// write 10 and 20 to opA and opB regs: operands
	writeReg32(0x18, 10);
	writeReg32(0x20, 20);
	cout << "ALU opA = " << readReg32(0x18) << " opB = " << readReg32(0x20) << endl;
	// start accel and wait until done
	writeReg32(0x00, 1);
	while(readReg32(0x00) & 0x2 != 0x2);
	// read the result
	cout << "result = " << readReg32(0x10) << endl;
	if(readReg32(0x10) == 10*20) {
	  cout << "Register r/w test succeeded" << endl;
  } else {
    cout << "Register r/w test failed" << endl;
  }
  deinit();
	return 0;
}
