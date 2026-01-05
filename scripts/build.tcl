#
# Vivado Build Script for FPGA Image Processor
#
# Author: Zeke Mohammed
# Date: October 2025
#
# Usage:
#   vivado -mode batch -source scripts/build.tcl
#   vivado -mode batch -source scripts/build.tcl -tclargs clean
#

set project_name "fpga_image_processor"
set project_dir "./vivado_project"
set rtl_dir "./rtl"
set constraints_dir "./constraints"
set output_dir "./build"

# Target device
set part "xc7a35tcpg236-1"

# Create project directory
file mkdir $project_dir
file mkdir $output_dir

# Check for clean argument
if {$argc > 0} {
    if {[lindex $argv 0] == "clean"} {
        puts "Cleaning project..."
        file delete -force $project_dir
        file delete -force $output_dir
        puts "Clean complete"
        exit
    }
}

puts "================================================================"
puts "Building FPGA Image Processor"
puts "================================================================"

# Create project
create_project $project_name $project_dir -part $part -force

# Add RTL source files
puts "\nAdding RTL sources..."
add_files [glob $rtl_dir/*.v]

# Add constraints
puts "Adding constraints..."
add_files -fileset constrs_1 $constraints_dir/basys3.xdc

# Set top module
set_property top top [current_fileset]

# Update compile order
update_compile_order -fileset sources_1

puts "\n================================================================"
puts "Running Synthesis"
puts "================================================================"

# Synthesis settings for optimization
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FANOUT_LIMIT 400 [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.KEEP_EQUIVALENT_REGISTERS true [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RESOURCE_SHARING off [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.NO_LC off [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.SHREG_MIN_SIZE 5 [get_runs synth_1]

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed"
    exit 1
}

puts "\n✓ Synthesis complete"

# Open synthesized design and report
open_run synth_1
report_utilization -file $output_dir/utilization_synth.rpt
report_timing_summary -file $output_dir/timing_synth.rpt

puts "\n================================================================"
puts "Running Implementation"
puts "================================================================"

# Implementation settings
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

# Run implementation
launch_runs impl_1 -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed"
    exit 1
}

puts "\n✓ Implementation complete"

# Open implemented design and generate reports
open_run impl_1

puts "\nGenerating reports..."
report_utilization -file $output_dir/utilization_impl.rpt
report_timing_summary -file $output_dir/timing_impl.rpt -max_paths 10
report_power -file $output_dir/power.rpt
report_drc -file $output_dir/drc.rpt
report_io -file $output_dir/io.rpt
report_clock_utilization -file $output_dir/clock_utilization.rpt

# Check timing
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]

puts "\nTiming Summary:"
puts "  Worst Setup Slack: [format %.3f $wns] ns"
puts "  Worst Hold Slack: [format %.3f $whs] ns"

if {$wns < 0 || $whs < 0} {
    puts "ERROR: Timing not met!"
    exit 1
}

puts "\n✓ Timing constraints met"

puts "\n================================================================"
puts "Generating Bitstream"
puts "================================================================"

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Bitstream generation failed"
    exit 1
}

# Copy bitstream to output directory
file copy -force $project_dir/$project_name.runs/impl_1/top.bit $output_dir/fpga_image_processor.bit

puts "\n✓ Bitstream generated: $output_dir/fpga_image_processor.bit"

puts "\n================================================================"
puts "Build Summary"
puts "================================================================"

# Print resource utilization
set util [report_utilization -return_string]
puts $util

puts "\n✓ Build complete!"
puts "Bitstream: $output_dir/fpga_image_processor.bit"
puts "Reports: $output_dir/"

exit
