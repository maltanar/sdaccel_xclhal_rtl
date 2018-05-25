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

# syntesize and export
create_clock -period $config_clkperiod -name default
csynth_design
export_design -format ip_catalog
exit 0
