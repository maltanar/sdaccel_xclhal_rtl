# sdaccel_xclhal_rtl
Examples for using the SDAccel XCL HAL library for interfacing RTL kernels.
The XCL HAL library provides low-level access to designs running on the FPGA,
such as reading and writing control/status registers directly from host code.

## Requirements
* Xilinx SDAccel 2017.4

## Quickstart
1. For the desired SDAccel platform, unzip the xclgemhal.zip found under the board installation folder 
(e.g. /path/to/xilinx_kcu1500_dynamic_5_0/xbinst/runtime/platforms/xilinx_kcu1500_dynamic_5_0/driver/xclgemhal.zip) 
to get the include folder /path/to/xilinx_kcu1500_dynamic_5_0/xbinst/runtime/platforms/xilinx_kcu1500_dynamic_5_0/driver/include

2. Ensure the XILINX_OPENCL environment variable is pointing to the root of the board installation, e.g.
/path/to/xilinx_kcu1500_dynamic_5_0/xbinst

3. Run "make all" in the root directory of this repository. This will take a while to complete.

4. Run "make run" to run the host application and run the test.

## Organization
* hls/ -- HLS sources to generate example accelerators, packed later as RTL kernels
* host/ -- host code using the XCL HAL for device access
* metadata/ -- dummy kernel.xml files for SDAccel RTL kernel packaging
* tcl/ -- scripts for HLS synthesis and SDAccel RTL kernel packaging

## TODO
* add memcpy example
* support the hw_emu flow
