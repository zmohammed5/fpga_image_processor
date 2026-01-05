# run_sim.tcl - Vivado Simulation Script
# Runs all testbenches for the FPGA Image Processing Accelerator
# Author: Zeke Mohammed | Date: October 2025

puts "=========================================="
puts "FPGA Image Processor - Simulation Suite"
puts "=========================================="

# Set project paths
set proj_dir [file dirname [info script]]/..
set rtl_dir $proj_dir/rtl
set sim_dir $proj_dir/sim

# Create simulation project
create_project sim_project $sim_dir/sim_project -part xc7a35tcpg236-1 -force

# Add RTL sources
add_files -fileset sources_1 [glob $rtl_dir/*.v]

# Add testbenches
add_files -fileset sim_1 $sim_dir/tb_convolution_engine.v
add_files -fileset sim_1 $sim_dir/tb_line_buffer.v
add_files -fileset sim_1 $sim_dir/tb_top.v

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Run convolution engine testbench
puts "\n--- Running Convolution Engine Testbench ---"
set_property top tb_convolution_engine [get_filesets sim_1]
launch_simulation
run all
close_sim

# Run line buffer testbench
puts "\n--- Running Line Buffer Testbench ---"
set_property top tb_line_buffer [get_filesets sim_1]
launch_simulation
run all
close_sim

# Run top-level integration testbench
puts "\n--- Running Top Module Testbench ---"
set_property top tb_top [get_filesets sim_1]
launch_simulation
run all

puts "\n=========================================="
puts "All simulations complete!"
puts "=========================================="
