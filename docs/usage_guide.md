# Usage Guide

## Getting Started

This guide walks you through setting up and using the FPGA Image Processing Accelerator.

## Hardware Setup

### Required Components

1. **Digilent Basys3 Board** (or compatible Artix-7 board)
2. **VGA Monitor** (640x480 @ 60Hz capable)
3. **VGA Cable** (15-pin D-sub)
4. **USB Cable** (Type-A to Micro-B for programming and UART)
5. **Host Computer** (Windows, Linux, or macOS)

### Connection Diagram

```
    +-------------+     VGA Cable     +-------------+
    |   Basys3    |------------------>|   Monitor   |
    |    FPGA     |                   +-------------+
    |             |
    |   USB Port  |<---- USB Cable ----- Host PC
    +-------------+
```

### Physical Connections

1. Connect VGA cable from Basys3 VGA port to monitor
2. Connect USB cable from Basys3 PROG port to PC
3. Power on the Basys3 using the slide switch (SW15)
4. Verify power LED illuminates

## Software Installation

### Prerequisites

- **Python 3.8+** with pip
- **Xilinx Vivado 2023.1+** (for building from source)
- **Git** (for cloning repository)

### Install Python Dependencies

```bash
# Clone the repository
git clone https://github.com/zmohammed5/fpga-image-processor
cd fpga-image-processor

# Install required packages
pip install -r python/requirements.txt
```

**Dependencies installed:**
- pyserial (serial communication)
- numpy (image processing)
- opencv-python (image I/O)
- tqdm (progress bars)
- matplotlib (optional, for plotting)

## Programming the FPGA

### Option 1: Use Pre-built Bitstream

```bash
# Navigate to project directory
cd fpga-image-processor

# Program FPGA (Linux/macOS)
bash scripts/program_fpga.sh

# Or on Windows (Vivado in PATH)
vivado -mode batch -source scripts/program_fpga.tcl
```

### Option 2: Build from Source

```bash
# Run full build flow
vivado -mode batch -source scripts/build.tcl

# This takes approximately 10 minutes and generates:
# - build/fpga_image_processor.bit (bitstream)
# - build/utilization_impl.rpt (resource usage)
# - build/timing_impl.rpt (timing analysis)
```

### Verify Programming

After programming, you should see:
- **LED0** ON = PLL locked (system clock active)
- **LED1-4** OFF = Idle state
- **VGA output** = Black screen (no image loaded)

## Uploading Images

### Basic Upload

```bash
# Linux/macOS
python python/upload_image.py --port /dev/ttyUSB0 --image lena.png

# Windows
python python/upload_image.py --port COM3 --image lena.png
```

### Upload with Preview

```bash
python python/upload_image.py --port /dev/ttyUSB0 --image photo.jpg --preview
```

This opens a window showing:
- Original image (left)
- Resized/converted image being sent (right)

### Supported Image Formats

| Format | Extension | Notes |
|--------|-----------|-------|
| JPEG | .jpg, .jpeg | Most common |
| PNG | .png | Supports transparency (ignored) |
| BMP | .bmp | Uncompressed |
| TIFF | .tif, .tiff | Professional format |

All images are automatically:
- Resized to 640x480
- Converted to grayscale
- Uploaded via UART (115200 baud)

### Finding Your Serial Port

```bash
# Linux
ls /dev/ttyUSB*

# macOS
ls /dev/cu.usbserial*

# Windows (in Python)
python -m serial.tools.list_ports
```

## Operating Modes

### Mode Selection

Use the buttons on the Basys3 board:

| Button | Name | Function |
|--------|------|----------|
| BTNC | Center | Cycle through modes |
| BTNL | Left | Initiate image upload |
| BTNR | Right | System reset |
| BTNU | Up | Reserved |
| BTND | Down | Reserved |

### Processing Modes

**Mode 0: Passthrough**
- Displays original uploaded image
- No processing applied
- LED3 and LED4 both OFF

**Mode 1: Edge Detection (Sobel)**
- Applies Sobel operator for edge extraction
- Highlights transitions and boundaries
- LED3 ON, LED4 OFF

**Mode 2: Gaussian Blur**
- Applies 3x3 Gaussian smoothing
- Reduces noise, softens image
- LED3 OFF, LED4 ON

### LED Status Indicators

| LED | Meaning |
|-----|---------|
| LED0 | PLL locked (always ON when running) |
| LED1 | Upload in progress (blinks during transfer) |
| LED2 | Upload complete (stays ON after upload) |
| LED3 | Edge detection mode active |
| LED4 | Gaussian blur mode active |
| LED5-15 | Unused |

## Running Benchmarks

### CPU vs FPGA Comparison

```bash
python python/benchmark.py --image test.jpg --output results.md
```

**Output includes:**
- CPU timing (NumPy implementation)
- FPGA timing (simulated from hardware measurements)
- Speedup calculation
- Markdown-formatted report

### Generate Performance Plots

```bash
python python/benchmark.py --image test.jpg --plot
```

Creates bar charts comparing CPU and FPGA performance.

## Troubleshooting

### No VGA Output

1. Check VGA cable connection (both ends)
2. Verify monitor is set to VGA input
3. Confirm LED0 is ON (PLL locked)
4. Try pressing BTNR to reset

### Upload Fails

1. Verify correct serial port (`python -m serial.tools.list_ports`)
2. Check USB cable connection
3. Ensure no other program is using the serial port
4. Try a lower baud rate: `--baud 9600`

### Image Displays Incorrectly

1. Press BTNC to cycle to passthrough mode
2. Verify image was resized correctly (check preview)
3. Ensure image is grayscale-compatible

### PLL Won't Lock (LED0 OFF)

1. Press BTNR for reset
2. Power cycle the board (SW15 off, wait 5 seconds, on)
3. Reprogram the FPGA

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Serial port not found" | Wrong port specified | List ports and try again |
| "Permission denied" | Port access restricted | Add user to dialout group (Linux) |
| "Timeout during upload" | Communication issue | Check cable, reset board |

## Advanced Usage

### Custom Images

For best results, pre-process images:

```python
import cv2

# Load image
img = cv2.imread('photo.jpg')

# Convert to grayscale
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

# Resize to 640x480
resized = cv2.resize(gray, (640, 480))

# Save for upload
cv2.imwrite('prepared.png', resized)
```

### Batch Processing

```bash
for img in images/*.jpg; do
    python python/upload_image.py --port /dev/ttyUSB0 --image "$img"
    sleep 2  # Wait for display
done
```

### Capturing Output

To capture the VGA output, use a VGA capture device or take a photo of the monitor. The captured image demonstrates the FPGA processing in action.

## Tips for Best Results

1. **High-contrast images** work best for edge detection
2. **Noise-free images** produce cleaner blur results
3. **Center important features** in the 640x480 frame
4. **Use natural lighting** when photographing VGA output for documentation

---

*Last updated: October 2025*
