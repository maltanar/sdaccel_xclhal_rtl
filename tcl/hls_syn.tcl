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

# quick-and-dirty tcl script for single-file HLS synthesis
# start reading args from index 2 since vivado HLS also passes -f tclname here
set config_proj_name      [lindex $::argv 2]
set config_hwsrc          [lindex $::argv 3]
set config_proj_part      [lindex $::argv 4]
set config_clkperiod      [lindex $::argv 5]
set config_toplevelfxn    [lindex $::argv 6]

puts "HLS project: $config_proj_name"
puts "HW source file: $config_hwsrc"
puts "Part: $config_proj_part"
puts "Clock period: $config_clkperiod ns"
puts "Top level function name: $config_toplevelfxn"

# set up project
open_project $config_proj_name
add_files $config_hwsrc -cflags "-std=c++0x"
set_top $config_toplevelfxn
open_solution sol1
set_part $config_proj_part
config_compile -name_max_length 300

# use 64-bit AXI MM addresses
config_interface -m_axi_addr64

# optionally prefix the RTL generated function names
if {$argc > 8} {
    set config_prefix [lindex $::argv 8]
    puts "Prefixing RTL function names with: $config_prefix"
    config_rtl -prefix "$config_prefix"
}

# synthesize
create_clock -period $config_clkperiod -name default
csynth_design

# optionally export the IP in the desired format
if {$argc > 7} {
    set config_ip_format [lindex $::argv 7]
    puts "Exporting IP in format: $config_ip_format"
    export_design -format $config_ip_format
}

exit 0
