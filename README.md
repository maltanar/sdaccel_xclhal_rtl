# sdaccel_xclhal_rtl
Examples for using the SDAccel XCL HAL library for interfacing RTL kernels.
The XCL HAL library provides low-level access to designs running on the FPGA,
such as reading and writing control/status registers directly from host code.

## Flow
The repo exemplifies the following flow:
1. Vivado HLS is called to generate Verilog from the HLS cpp sources.
2. The generated Verilog is packaged into an SDAccel-compliant IP block.
3. The generated IP block is packaged into an SDAccel .xo archive.
4. The .xo archive is linked into the specified platform DSA to generate the .xclbin archive containing the bitfile.
5. The host application flashes the generated xclbin and performs low-level control of the accelerator using XCL HAL.

## Examples in this repo
There are two examples in the repo, reg2reg and memcpy.

The reg2reg example consists of:
* a tiny "ALU" coded in Vivado HLS, reading from AXI lite registers and writing the result back to AXI lite.
* host code using XCL HAL to read and write the AXI lite registers of the accelerator directly.
* scripts to go through HLS -> RTL -> XO -> XCLBIN and for compiling the host code

The memcpy example consists of:
* a simple memcpy accelerator coded in Vivado HLS, copying a buffer from the FPGA DRAM back into the FPGA DRAM, and returning the sum of the buffer elements over AXI lite.
* host code using XCL HAL to read and write the AXI lite registers of the accelerator, and to copy buffers between the host and FPGA DRAMs.
* scripts to go through HLS -> RTL -> XO -> XCLBIN and for compiling the host code 

## Requirements
* Xilinx SDAccel 2017.4

## Quickstart
1. Ensure the XILINX_SDX environment variable is pointing to the root of the SDx installation.

2. Set the PLATFORM and DEVICE variables in the Makefile. The default DEVICE (FPGA part name) is xcku115-flvb2104-2-e and the PLATFORM (SDx DSA name) is xilinx_kcu1500_dynamic_5_0. Ensure that the selected platform is correctly installed in SDx.

3. Set the TESTCASE variable to either reg2reg or memcpy.

4. Run "make all" in the root directory of this repository. This will take a while to complete.

5. Run "make run" to run the host application and run the test.

## Organization
* hls/ -- HLS sources to generate example accelerators, packed later as RTL kernels
* host/ -- host code using the XCL HAL for device access
* metadata/ -- dummy kernel.xml files for SDAccel RTL kernel packaging
* tcl/ -- scripts for HLS synthesis and SDAccel RTL kernel packaging

## TODO
* support the hw_emu flow
