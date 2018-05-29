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

# variables you may want to override when running make
# name of testcase to execute: so far only reg2reg 
TESTCASE ?= reg2reg
# clock frequency targets, provided separately for HLS and the full bitfile
HLS_CLK_NS ?= "10.0"
XCLBIN_FREQ_MHZ ?= 100
# SDAccel flow, currently only hw -- hw_emu is in the works
MODE ?= hw
# FPGA part name
PART ?= "xcku115-flvb2104-2-e"
# SDAccel DSA (platform) to target
PLATFORM ?= "xilinx_kcu1500_dynamic_5_0"

# internal Makefile variables, should be no need to modify these
ROOT_DIR := $(shell readlink -f .)
BUILD_DIR := $(ROOT_DIR)/build-$(TESTCASE)
# arguments for HLS
HLS_INPUT := $(shell readlink -f hls/$(TESTCASE).cpp) 
HLS_SCRIPT := $(shell readlink -f tcl/hls_syn.tcl)
HLS_PROJNAME := hls_syn
HLS_PROJDIR := $(BUILD_DIR)/$(HLS_PROJNAME)
HLS_OUTPUT := $(HLS_PROJDIR)/sol1/impl/ip
# arguments for the RTL kernel packager
XO_OUTPUT := $(BUILD_DIR)/$(TESTCASE).xo
XO_SCRIPT := $(shell readlink -f tcl/gen_xo.tcl)
KERNELXML_INPUT := $(shell readlink -f metadata/kernel_$(TESTCASE).xml)
# arguments for xocc / xclbin generation
XCLBIN_FREQ_OPTS := "0:$(XCLBIN_FREQ_MHZ)|1:$(XCLBIN_FREQ_MHZ)"
XCLBIN_OPTIMIZE := 0
XCLBIN_OUTPUT := $(BUILD_DIR)/$(TESTCASE)-$(MODE).xclbin
# host application
HOST_SRCS := $(shell readlink -f host/$(TESTCASE).cpp) $(shell readlink -f host/xclhal_utils.c)
HOST_OUTPUT := $(BUILD_DIR)/host-$(MODE)
EMCONFIG := $(BUILD_DIR)/emconfig.json
ifeq ($(MODE),hw)
	# use xclgemdrv for actual hardware
	# TODO make sure that XILINX_OPENCL is defined
	# remember to unzip the xclgemhal.zip on this path
	HOST_XCLHAL_INCL_PATH := $(XILINX_OPENCL)/runtime/platforms/$(PLATFORM)/driver/include
	HOST_DRV_LIB_PATH := $(XILINX_OPENCL)/runtime/lib/x86_64
	HOST_XCLHAL_LIB_PATH := $(XILINX_OPENCL)/runtime/platforms/$(PLATFORM)/driver
	HOST_XCLHAL_LIB_NAME := xclgemdrv
	XOCC_OPTS := 
	EMU_EXTRA_DEPENDS :=
        CSR_BASE_ADDR := 0x1800000
else ifeq ($(MODE),hw_emu)
	# use the generic PCIe platform emulation driver
	# TODO make sure that XILINX_SDX is defined
	HOST_XCLHAL_INCL_PATH := $(XILINX_SDX)/runtime/driver/include
	HOST_DRV_LIB_PATH := $(XILINX_SDX)/runtime/lib/x86_64
	HOST_XCLHAL_LIB_PATH := $(XILINX_SDX)/data/emulation/hw_em/generic_pcie/driver
	HOST_XCLHAL_LIB_NAME := hw_em	
	XOCC_OPTS := --save-temps -g
	EMU_EXTRA_DEPENDS := $(EMCONFIG)
        CSR_BASE_ADDR := 0x0
endif

HOST_CXX_OPTS := -std=c++11 -DCSR_BASE_ADDR=$(CSR_BASE_ADDR)
HOST_INCL_PATHS := -I$(HOST_XCLHAL_INCL_PATH) -I$(shell readlink -f host)
HOST_LIB_PATHS := -L$(HOST_XCLHAL_LIB_PATH) -L$(HOST_DRV_LIB_PATH)
HOST_LIBS := -lxilinxopencl -l$(HOST_XCLHAL_LIB_NAME) -lpthread -lrt -lstdc++

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HLS_OUTPUT): $(BUILD_DIR)
	cd $(BUILD_DIR); vivado_hls -f $(HLS_SCRIPT) $(HLS_PROJNAME) $(HLS_INPUT) $(PART) $(HLS_CLK_NS) $(TESTCASE)

$(XO_OUTPUT): $(HLS_OUTPUT)
	cd $(BUILD_DIR); vivado -mode batch -source $(XO_SCRIPT) -tclargs $(XO_OUTPUT) $(TESTCASE) $(HLS_OUTPUT) $(KERNELXML_INPUT)

$(XCLBIN_OUTPUT): $(XO_OUTPUT)
	cd $(BUILD_DIR); xocc --link $(XOCC_OPTS) --target $(MODE) --kernel_frequency $(XCLBIN_FREQ_OPTS) --optimize $(XCLBIN_OPTIMIZE) --platform $(PLATFORM) $(XO_OUTPUT) -o $(XCLBIN_OUTPUT)

$(HOST_OUTPUT): $(BUILD_DIR)
	g++ $(HOST_CXX_OPTS) $(HOST_INCL_PATHS) $(HOST_LIB_PATHS) $(HOST_LIBS) $(HOST_SRCS) -o $(HOST_OUTPUT)

$(EMCONFIG):
	emconfigutil --platform $(PLATFORM) --nd 1 -s --od $(BUILD_DIR)

all: $(XCLBIN_OUTPUT) $(HOST_OUTPUT)

run: $(XCLBIN_OUTPUT) $(HOST_OUTPUT) $(EMU_EXTRA_DEPENDS)
	LD_LIBRARY_PATH=$(HOST_DRV_LIB_PATH):$(HOST_XCLHAL_LIB_PATH) $(HOST_OUTPUT) $(XCLBIN_OUTPUT)

clean:
	rm -rf $(BUILD_DIR)
	
.PHONY: hls xo xclbin host run all clean

hls: $(HLS_OUTPUT)
xo: $(XO_OUTPUT)
xclbin: $(XCLBIN_OUTPUT)
host: $(HOST_OUTPUT)
