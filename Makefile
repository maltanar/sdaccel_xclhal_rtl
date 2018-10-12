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
# SDAccel flow, currently only hw (hw_emu does not yet work)
MODE ?= hw
# FPGA part name
PART ?= "xcku115-flvb2104-2-e"
# SDAccel DSA (platform) to target
PLATFORM ?= "xilinx_kcu1500_dynamic_5_0"

# internal Makefile variables, should be no need to modify these
ROOT_DIR := $(shell readlink -f .)
BUILD_DIR := $(ROOT_DIR)/build-$(TESTCASE)
# variables for HLS synthesis
HLS_INPUT := $(shell readlink -f hls/$(TESTCASE).cpp) 
HLS_SCRIPT := $(shell readlink -f tcl/hls_syn.tcl)
HLS_PROJNAME := hls_syn
HLS_PROJDIR := $(BUILD_DIR)/$(HLS_PROJNAME)
HLS_OUTPUT := $(HLS_PROJDIR)/sol1/syn/verilog
# variables for the IP packager
HDL_IP_SCRIPT := $(shell readlink -f tcl/package_ip.tcl)
DCP_IP_SCRIPT := $(shell readlink -f tcl/package_dcp.tcl)
IP_OUTPUT := $(BUILD_DIR)/ip
# variables for the Block Design assembler
BD_SCRIPT := $(shell readlink -f tcl/ipi_bd.tcl)
# variables for the RTL kernel packager
XO_OUTPUT := $(BUILD_DIR)/$(TESTCASE).xo
XO_SCRIPT := $(shell readlink -f tcl/gen_xo.tcl)
KERNELXML_INPUT := $(shell readlink -f metadata/kernel_$(TESTCASE).xml)
# variables for xocc / xclbin generation
XCLBIN_FREQ_OPTS := "0:$(XCLBIN_FREQ_MHZ)|1:$(XCLBIN_FREQ_MHZ)"
XCLBIN_OPTIMIZE := 0
XCLBIN_OUTPUT := $(BUILD_DIR)/$(TESTCASE)-$(MODE).xclbin
# variables for the host application
HOST_SRCS := $(shell readlink -f host/$(TESTCASE).cpp) $(shell readlink -f host/xclhal_utils.c)
HOST_OUTPUT := $(BUILD_DIR)/host-$(MODE)
EMCONFIG := $(BUILD_DIR)/emconfig.json
ifeq ($(MODE),hw)
	HOST_XCLHAL_INCL_PATH := $(XILINX_SDX)/runtime/driver/include
	HOST_DRV_LIB_PATH := $(XILINX_SDX)/runtime/lib/x86_64
	HOST_XCLHAL_LIB_PATH := $(XILINX_SDX)/platforms/$(PLATFORM)/sw/driver/gem
	HOST_XCLHAL_LIB_NAME := xclgemdrv
	XOCC_OPTS := 
	EMU_EXTRA_DEPENDS :=
	CSR_BASE_ADDR := 0x1800000 
	# TODO can retrieve the CSR_BASE_ADDR from address_map.xml -- something like this
	# cat $(BUILD_DIR)/address_map.xml  | grep s_axi_control | tr ' ' '\n' | grep baseAddr | tr '=' '\n' | grep 0x
	# all produced hw seems to use 0x1800000 for now so static def should be safe for a while
	ENVVAR_DEPENDS := envvar_sdx
endif

HOST_CXX_OPTS := -std=c++11 -DCSR_BASE_ADDR=$(CSR_BASE_ADDR) -DFCLK_MHZ=$(XCLBIN_FREQ_MHZ)
HOST_INCL_PATHS := -I$(HOST_XCLHAL_INCL_PATH) -I$(shell readlink -f host)
HOST_LIB_PATHS := -L$(HOST_XCLHAL_LIB_PATH) -L$(HOST_DRV_LIB_PATH)
HOST_LIBS := -lxilinxopencl -l$(HOST_XCLHAL_LIB_NAME) -lpthread -lrt -lstdc++

.PHONY: hls ip xo xclbin host run all clean envvar_sdx

envvar_sdx:
ifndef XILINX_SDX
	$(error XILINX_SDX is undefined)
endif

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HLS_OUTPUT): | $(BUILD_DIR)
ifeq ($(TESTCASE),streaminc)
	cd $(BUILD_DIR); vivado_hls -f $(HLS_SCRIPT) $(HLS_PROJNAME)_dmainout $(HLS_INPUT) $(PART) $(HLS_CLK_NS) dmainout ip_catalog
	cd $(BUILD_DIR); vivado_hls -f $(HLS_SCRIPT) $(HLS_PROJNAME)_streamadd $(HLS_INPUT) $(PART) $(HLS_CLK_NS) streamadd ip_catalog
	cd $(BUILD_DIR); vivado -mode batch -source $(BD_SCRIPT) -tclargs $(TESTCASE) $(BUILD_DIR) $(HLS_OUTPUT) $(PART)
else
	cd $(BUILD_DIR); vivado_hls -f $(HLS_SCRIPT) $(HLS_PROJNAME) $(HLS_INPUT) $(PART) $(HLS_CLK_NS) $(TESTCASE)
endif

$(IP_OUTPUT): $(HLS_OUTPUT)
	cd $(BUILD_DIR); vivado -mode batch -source $(HDL_IP_SCRIPT) -tclargs $(TESTCASE) $(HLS_OUTPUT) $(IP_OUTPUT)
ifeq ($(TESTCASE),streaminc)
	cd $(BUILD_DIR); vivado -mode batch -source $(DCP_IP_SCRIPT) -tclargs $(TESTCASE) $(HLS_OUTPUT) $(IP_OUTPUT) $(PART)
endif

$(XO_OUTPUT): $(IP_OUTPUT)
	cd $(BUILD_DIR); vivado -mode batch -source $(XO_SCRIPT) -tclargs $(XO_OUTPUT) $(TESTCASE) $(IP_OUTPUT) $(KERNELXML_INPUT)

$(XCLBIN_OUTPUT): $(XO_OUTPUT) $(ENVVAR_DEPENDS)
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

hls: $(HLS_OUTPUT)
ip: $(IP_OUTPUT)
xo: $(XO_OUTPUT)
xclbin: $(XCLBIN_OUTPUT)
host: $(HOST_OUTPUT)
all: xclbin host
