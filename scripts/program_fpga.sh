#!/bin/bash
#
# FPGA Programming Script
#
# Programs Basys3 board with generated bitstream
#
# Author: Zeke Mohammed
# Date: October 2025
#

set -e  # Exit on error

BITSTREAM="./build/fpga_image_processor.bit"
VIVADO_CMD="vivado"

echo "================================================================"
echo "FPGA Programming Script"
echo "================================================================"

# Check if bitstream exists
if [ ! -f "$BITSTREAM" ]; then
    echo "Error: Bitstream not found: $BITSTREAM"
    echo "Run 'make build' first"
    exit 1
fi

echo "✓ Bitstream found: $BITSTREAM"

# Create TCL script for programming
cat > /tmp/program_fpga.tcl <<'EOF'
# Auto-detect and program FPGA

# Open hardware manager
open_hw_manager

# Connect to hardware server
connect_hw_server -url localhost:3121 -allow_non_jtag

# Refresh and get targets
refresh_hw_server
current_hw_target [get_hw_targets */xilinx_tcf/Digilent/*]
open_hw_target

# Get device
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device -update_hw_probes false [current_hw_device]

# Program device
set_property PROGRAM.FILE {./build/fpga_image_processor.bit} [current_hw_device]
program_hw_devices [current_hw_device]

# Verify
if {[get_property PROGRAM.DONE [current_hw_device]]} {
    puts "\n✓ Programming successful!"
} else {
    puts "\n✗ Programming failed!"
    exit 1
}

# Close
close_hw_target
disconnect_hw_server
close_hw_manager
exit
EOF

echo ""
echo "Detecting FPGA hardware..."
echo ""

# Run Vivado in batch mode
$VIVADO_CMD -mode batch -source /tmp/program_fpga.tcl

echo ""
echo "================================================================"
echo "✓ FPGA programmed successfully!"
echo "================================================================"
echo ""
echo "Next steps:"
echo "  1. Connect VGA monitor"
echo "  2. Upload image: python python/upload_image.py --port /dev/ttyUSB0 --image test.jpg"
echo "  3. Press buttons to switch modes (passthrough/edge/blur)"
echo ""

# Cleanup
rm -f /tmp/program_fpga.tcl
