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
# other options to pass to g++ for host app
HOST_CXX_OPTS := -std=c++11
# TODO make sure that XILINX_OPENCL is defined
# host app include paths -- remember to unzip the xclgemhal.zip on this path
HOST_XCLHAL_INCL_PATH := $(XILINX_OPENCL)/runtime/platforms/$(PLATFORM)/driver/include
HOST_INCL_PATHS := -I$(HOST_XCLHAL_INCL_PATH) -I$(shell readlink -f host)
# host app lib paths and libs
HOST_XCLHAL_LIB_PATH := "$(XILINX_OPENCL)/runtime/platforms/$(PLATFORM)/driver"
HOST_DRV_LIB_PATH := "$(XILINX_OPENCL)/runtime/lib/x86_64"
HOST_LIB_PATHS := -L$(HOST_XCLHAL_LIB_PATH) -L$(HOST_DRV_LIB_PATH)
HOST_LIBS := -lxclgemdrv -lpthread -lrt -lstdc++

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HLS_OUTPUT): $(BUILD_DIR)
	cd $(BUILD_DIR); vivado_hls -f $(HLS_SCRIPT) $(HLS_PROJNAME) $(HLS_INPUT) $(PART) $(HLS_CLK_NS) $(TESTCASE)

$(XO_OUTPUT): $(HLS_OUTPUT)
	cd $(BUILD_DIR); vivado -mode batch -source $(XO_SCRIPT) -tclargs $(XO_OUTPUT) $(TESTCASE) $(HLS_OUTPUT) $(KERNELXML_INPUT)

$(XCLBIN_OUTPUT): $(XO_OUTPUT)
	cd $(BUILD_DIR); xocc --link --target $(MODE) --kernel_frequency $(XCLBIN_FREQ_OPTS) --optimize $(XCLBIN_OPTIMIZE) --platform $(PLATFORM) $(XO_OUTPUT) -o $(XCLBIN_OUTPUT)

$(HOST_OUTPUT):
	g++ $(HOST_CXX_OPTS) $(HOST_INCL_PATHS) $(HOST_LIB_PATHS) $(HOST_LIBS) $(HOST_SRCS) -o $(HOST_OUTPUT)

all: $(XCLBIN_OUTPUT) $(HOST_OUTPUT)

clean:
	rm -rf $(BUILD_DIR)
	
.PHONY: hls xo xclbin host all clean

hls: $(HLS_OUTPUT)
xo: $(XO_OUTPUT)
xclbin: $(XCLBIN_OUTPUT)
host: $(HOST_OUTPUT)
