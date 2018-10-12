if { $::argc != 4 } {
    puts "ERROR: Program \"$::argv0\" requires 4 arguments!\n"
    puts "Usage: $::argv0 <kernel_name> <in_path_to_hdl> <out_path_to_ip> <fpga_part>\n"
    exit
}

set krnl_name   [lindex $::argv 0]
set path_to_hdl [lindex $::argv 1]
set path_to_ip  [lindex $::argv 2]
set proj_part   [lindex $::argv 3]
set clkperiod   [lindex $::argv 4]
set ip_format   [lindex $::argv 5]

# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "."

# Use origin directory path location variable, if specified in the tcl shell
if { [info exists ::origin_dir_loc] } {
  set origin_dir $::origin_dir_loc
}

# Set the project name
set project_name "assemble_bd"

# Use project name variable, if specified in the tcl shell
if { [info exists ::user_project_name] } {
  set project_name $::user_project_name
}

# Create project
create_project -force ${project_name} ./${project_name} -part ${proj_part}

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Reconstruct message rules
# None

# Set project properties
set obj [current_project]
set_property -name "part" -value "${proj_part}" -objects $obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/${project_name}.cache/ip" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_MEMORY" -objects $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set IP repository paths
set obj [get_filesets sources_1]
set_property "ip_repo_paths" "[file normalize "$path_to_hdl"]" $obj

# Rebuild user ip_repo's index before adding any source files
update_ip_catalog -rebuild

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]
# Set 'sources_1' fileset file properties for remote files
# None

# Set 'sources_1' fileset file properties for local files
# None

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Empty (no sources present)

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
# Empty (no sources present)

# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]


# Adding sources referenced in BDs, if not already added


# Proc to create BD
proc cr_bd { parentCell } {

  # CHANGE DESIGN NAME HERE
  set design_name blockdesign

  common::send_msg_id "BD_TCL-003" "INFO" "Currently there is no design <$design_name> in project, so creating one..."

  create_bd_design $design_name

  set bCheckIPsPassed 1
  ##################################################################
  # CHECK IPs
  ##################################################################
  set bCheckIPs 1
  if { $bCheckIPs == 1 } {
     set list_check_ips "\ 
  xilinx.com:hls:dmainout:1.0\
  xilinx.com:hls:streamadd:1.0\
  "

   set list_ips_missing ""
   common::send_msg_id "BD_TCL-006" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_msg_id "BD_TCL-115" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

  }

  if { $bCheckIPsPassed != 1 } {
    common::send_msg_id "BD_TCL-1003" "WARNING" "Will not continue with creation of design due to the error(s) above."
    return 3
  }

  variable script_folder

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create clock and reset ports according to SDx spec
  create_bd_port -dir I -type clk ap_clk
  set_property CONFIG.FREQ_HZ 250000000 [get_bd_ports ap_clk]
  create_bd_port -dir I -type rst ap_rst_n
  set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports ap_rst_n]

  # Create instances
  set dmainout_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:dmainout:1.0 dmainout_0 ]
  set streamadd_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:streamadd:1.0 streamadd_0 ]
  set streamadd_1 [ create_bd_cell -type ip -vlnv xilinx.com:hls:streamadd:1.0 streamadd_1 ]

  save_bd_design
  
  # Make AXI interfaces external and rename them to standard names
  make_bd_intf_pins_external  [get_bd_intf_pins dmainout_0/m_axi_gmem]
  make_bd_intf_pins_external  [get_bd_intf_pins dmainout_0/s_axi_control]
  set_property name m_axi_gmem [get_bd_intf_ports m_axi_gmem_0]
  set_property name s_axi_control [get_bd_intf_ports s_axi_control_0]
  
  foreach SRC [list dmainout_0 streamadd_0 streamadd_1] DST [list streamadd_0 streamadd_1 dmainout_0] {
    set OUTWB [get_property [list CONFIG.TDATA_NUM_BYTES] [get_bd_intf_pins ${SRC}/output_V_V]]
    set INWB [get_property [list CONFIG.TDATA_NUM_BYTES] [get_bd_intf_pins ${DST}/input_V_V]]
    if {$OUTWB != $INWB} {
      puts "Connecting $SRC to $DST through data width converter (${OUTWB}B -> ${INWB}B)"
      create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 dwc_${SRC}_${DST}
      set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $OUTWB] [get_bd_cells dwc_${SRC}_${DST}]
      set_property -dict [list CONFIG.M_TDATA_NUM_BYTES $INWB] [get_bd_cells dwc_${SRC}_${DST}]
      connect_bd_intf_net [get_bd_intf_pins ${SRC}/output_V_V] [get_bd_intf_pins dwc_${SRC}_${DST}/S_AXIS]
      connect_bd_intf_net [get_bd_intf_pins dwc_${SRC}_${DST}/M_AXIS] [get_bd_intf_pins ${DST}/input_V_V]
      connect_bd_net [get_bd_ports ap_clk] [get_bd_pins dwc_${SRC}_${DST}/aclk]
      connect_bd_net [get_bd_ports ap_rst_n] [get_bd_pins dwc_${SRC}_${DST}/aresetn]
    } else {
      puts "Connecting $SRC to $DST directly"
      connect_bd_intf_net [get_bd_intf_pins ${SRC}/output_V_V] [get_bd_intf_pins ${DST}/input_V_V]
    }
  }

  # Create port connections
  connect_bd_net [get_bd_ports ap_clk] [get_bd_pins dmainout_0/ap_clk] [get_bd_pins streamadd_0/ap_clk] [get_bd_pins streamadd_1/ap_clk]
  connect_bd_net [get_bd_ports ap_rst_n] [get_bd_pins dmainout_0/ap_rst_n] [get_bd_pins streamadd_0/ap_rst_n] [get_bd_pins streamadd_1/ap_rst_n]

  # Create constant 1 for start and continue lines
  create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
  set_property -dict [list CONFIG.CONST_VAL {1}] [get_bd_cells xlconstant_0]
  connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins streamadd_0/ap_start] [get_bd_pins streamadd_1/ap_start] [get_bd_pins streamadd_0/ap_continue] [get_bd_pins streamadd_1/ap_continue]

  # Auto-assign addresses (TODO: check)
  exclude_bd_addr_seg [get_bd_addr_segs dmainout_0/Data_m_axi_gmem/SEG_m_axi_gmem_Reg]
  exclude_bd_addr_seg [get_bd_addr_segs s_axi_control/SEG_dmainout_0_Reg]

  # Restore current instance
  current_bd_instance $oldCurInst

  save_bd_design
  close_bd_design $design_name 
}
# End of cr_bd_resnet50()
cr_bd ""
set_property SYNTH_CHECKPOINT_MODE "Hierarchical" [ get_files blockdesign.bd ] 
puts "INFO: Project created:$project_name"

# Do OOC synthesis
generate_target all [get_files blockdesign.bd]
catch { config_ip_cache -export [get_ips -all blockdesign_dmainout_0_0] }
catch { config_ip_cache -export [get_ips -all blockdesign_streamadd_0_0] }
catch { config_ip_cache -export [get_ips -all blockdesign_streamadd_1_0] }
catch { config_ip_cache -export [get_ips -all blockdesign_xlconstant_0_0] }
export_ip_user_files -of_objects [get_files blockdesign.bd] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] blockdesign.bd]
launch_runs -jobs 4 {blockdesign_dmainout_0_0_synth_1 blockdesign_streamadd_0_0_synth_1 blockdesign_streamadd_1_0_synth_1 blockdesign_xlconstant_0_0_synth_1}

# Create wrapper
make_wrapper -files [get_files blockdesign.bd] -import -fileset sources_1 -top

# Synthesize toplevel
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
launch_runs synth_1
wait_on_run synth_1
open_run synth_1 -name synth_1

# Export EDIF netlist and stub
file mkdir $path_to_ip
write_verilog -force -mode synth_stub $path_to_ip/$krnl_name.v
write_checkpoint -force $path_to_ip/$krnl_name.dcp
write_xdc -force $path_to_ip/$krnl_name.xdc

close_project
