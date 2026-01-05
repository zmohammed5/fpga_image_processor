# System Architecture

## Overview

The FPGA Image Processing Accelerator uses a pipelined datapath architecture designed for maximum throughput while maintaining low resource utilization. This document details the system organization, module interactions, and key design decisions.

## Top-Level Block Diagram

```
                              +------------------+
                              |   Clock Wizard   |
                              | (100MHz -> 25MHz)|
                              +--------+---------+
                                       |
           +---------------------------+---------------------------+
           |                           |                           |
           v                           v                           v
    +------+------+            +-------+-------+           +-------+-------+
    |  UART RX    |            | Image Buffer  |           | VGA Controller|
    | (115200 bd) |----------->| (640x480x8b)  |---------->| (60Hz output) |
    +-------------+            +-------+-------+           +---------------+
                                       |
                                       v
                          +------------+------------+
                          |  Processing Pipeline   |
                          |                        |
                          |  +------------------+  |
                          |  | Line Buffers (3) |  |
                          |  +--------+---------+  |
                          |           |            |
                          |  +--------v---------+  |
                          |  | Convolution Eng. |  |
                          |  +--------+---------+  |
                          |           |            |
                          |  +--------v---------+  |
                          |  | Mode Selection   |  |
                          |  | (Edge/Blur/Pass) |  |
                          |  +------------------+  |
                          +------------------------+
```

## Module Descriptions

### 1. Top Module (`top.v`)

The top module integrates all subsystems and handles:
- Clock distribution from PLL
- Reset synchronization across clock domains
- Mode control via debounced button inputs
- LED status indicators
- I/O connections to board pins

**Key Design Decision:** All clock domain crossings are properly synchronized using dual flip-flop synchronizers. This prevents metastability issues that plagued early prototypes.

### 2. Convolution Engine (`convolution_engine.v`)

The heart of the processing pipeline - a 7-stage systolic array architecture.

**Pipeline Stages:**
1. **Stage 1 - Input Register:** Captures incoming pixel, manages addressing
2. **Stage 2 - Window Extract:** Reads 3x3 neighborhood from line buffers
3. **Stage 3 - Multiply (Gx):** 9 parallel DSP48E1 multiplications for horizontal gradient
4. **Stage 4 - Multiply (Gy):** 9 parallel DSP48E1 multiplications for vertical gradient
5. **Stage 5 - Accumulate:** Adder tree for MAC results
6. **Stage 6 - Normalize:** Fixed-point scaling and magnitude calculation
7. **Stage 7 - Saturate:** Clamp to 8-bit output range

**Why 7 stages?** Timing analysis showed the critical path was in the multiply-accumulate chain. Splitting this across 4 stages (3-6) allowed us to hit 120MHz with positive slack. Like blueprinting an engine block - you identify the bottleneck and open it up.

### 3. Line Buffer (`line_buffer.v`)

Triple-line circular buffer using block RAM primitives.

```
        New Pixel In
             |
             v
    +--------+--------+
    |   Line Buffer 2 | <-- Current row
    +-----------------+
    |   Line Buffer 1 | <-- Previous row
    +-----------------+
    |   Line Buffer 0 | <-- Two rows back
    +-----------------+
             |
             v
      3x3 Window Out
```

**Implementation:** Uses 3 RAMB36E1 primitives (each stores one 640-pixel line). Dual-port configuration enables simultaneous read/write for back-to-back pixel processing.

### 4. Edge Detector (`edge_detector.v`)

Implements the Sobel operator for gradient-based edge detection.

**Sobel Kernels:**
```
Gx = [-1  0  1]     Gy = [-1 -2 -1]
     [-2  0  2]          [ 0  0  0]
     [-1  0  1]          [ 1  2  1]
```

**Magnitude Calculation:**
Using the approximation `|G| = |Gx| + |Gy|` instead of `sqrt(Gx^2 + Gy^2)` to avoid the expensive square root operation. The visual difference is negligible, but the resource savings are significant.

### 5. Gaussian Blur (`gaussian_blur.v`)

3x3 Gaussian smoothing filter for noise reduction.

**Kernel (normalized):**
```
    [1  2  1]
G = [2  4  2] / 16
    [1  2  1]
```

**Fixed-Point Implementation:** Kernel coefficients are pre-scaled, and the division by 16 is a simple 4-bit right shift. No actual division hardware required.

### 6. VGA Controller (`vga_controller.v`)

Generates timing signals for 640x480 @ 60Hz VGA output.

**Timing Parameters:**
| Parameter | Value |
|-----------|-------|
| Pixel Clock | 25.175 MHz |
| H Active | 640 pixels |
| H Front Porch | 16 pixels |
| H Sync | 96 pixels |
| H Back Porch | 48 pixels |
| V Active | 480 lines |
| V Front Porch | 10 lines |
| V Sync | 2 lines |
| V Back Porch | 33 lines |

### 7. UART Receiver (`uart_rx.v`)

Receives image data from host PC at 115200 baud.

**Features:**
- 16x oversampling for robust bit detection
- Majority voting on sample values
- Frame error detection
- Double-buffered output

**Upload Time:** 640 x 480 x 8 bits / 115200 baud = ~26.7 seconds per frame

### 8. Image Buffer (`image_buffer.v`)

Dual-port frame buffer storing the input image.

**Specifications:**
- Capacity: 307,200 bytes (640 x 480 x 8-bit grayscale)
- Implementation: 8 RAMB36E1 tiles (36Kb each)
- Port A: Write (from UART RX)
- Port B: Read (to processing pipeline and VGA)

## Clock Domains

The system operates with two clock domains:

1. **Processing Domain (100 MHz):** All processing logic, UART receiver
2. **VGA Domain (25 MHz):** VGA timing and pixel output

**Clock Domain Crossing:**
- Processed pixel data crosses from 100MHz to 25MHz
- Uses gray-code FIFO with proper synchronization
- Depth of 8 entries provides sufficient buffering

## Memory Architecture

| Component | Type | Size | Utilization |
|-----------|------|------|-------------|
| Line Buffers | RAMB36E1 | 3 x 36Kb | 6% |
| Frame Buffer | RAMB36E1 | 8 x 36Kb | 16% |
| UART FIFO | RAMB18E1 | 1 x 18Kb | 2% |
| **Total BRAM** | | | **16%** |

## Fixed-Point Arithmetic

The design uses Q8.8 fixed-point format (8 integer bits, 8 fractional bits).

**Why Q8.8?**
- Provides sufficient precision for convolution (validated < 0.5% error vs. floating-point)
- Fits efficiently in 16-bit DSP48E1 multipliers
- Simple truncation for final 8-bit output

**Overflow Handling:**
All intermediate results are computed with extended precision (24-bit accumulators), then saturated to the output range. This prevents wraparound artifacts visible in earlier fixed-point implementations.

## Design Tradeoffs

| Decision | Alternative Considered | Rationale |
|----------|----------------------|-----------|
| Systolic array | Parallel multipliers | Better timing closure at 120MHz |
| Q8.8 fixed-point | Integer-only | Kernel accuracy for Gaussian blur |
| Triple line buffer | Shift register | Lower BRAM usage, same throughput |
| 7-stage pipeline | 5-stage | Required for 120MHz target |

## Lessons Learned

1. **Start with timing constraints:** Defining timing targets upfront guided architectural decisions
2. **Simulate before synthesize:** Behavioral testbenches caught issues early
3. **Leave headroom:** 20% timing margin proved valuable during integration
4. **Document as you build:** Much easier than retroactive documentation

---

*Author: Zeke Mohammed*
*Last Updated: October 2025*
