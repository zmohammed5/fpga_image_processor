# Theory: Image Processing Fundamentals

## Introduction

This document covers the mathematical foundations behind the image processing operations implemented in the FPGA accelerator.

## Digital Image Representation

### Pixels and Intensity

A digital grayscale image is a 2D matrix of intensity values:

```
I(x, y) where:
  - x = column position (0 to width-1)
  - y = row position (0 to height-1)
  - I = intensity value (0 to 255 for 8-bit images)
```

For this implementation:
- **Resolution:** 640 x 480 pixels
- **Bit depth:** 8 bits per pixel
- **Dynamic range:** 0 (black) to 255 (white)

### Coordinate System

```
    (0,0)------> x (columns)
      |
      |
      v
      y (rows)
```

The origin is at the top-left corner, matching the VGA scan order.

## Convolution

### Definition

2D convolution is a mathematical operation that combines an input image with a kernel (filter) to produce an output image:

```
         M-1  N-1
O(x,y) =  SUM  SUM  I(x-i, y-j) * K(i, j)
         i=0  j=0
```

Where:
- `O(x,y)` = output pixel
- `I(x,y)` = input image
- `K(i,j)` = kernel coefficients
- `M x N` = kernel dimensions (3x3 in our implementation)

### Visual Representation

```
    Input Image              Kernel              Output Image
+---+---+---+---+---+    +---+---+---+
| a | b | c | d | e |    |k00|k01|k02|    +---+---+---+---+---+
+---+---+---+---+---+    +---+---+---+    |   |   | O |   |   |
| f | g | h | i | j |    |k10|k11|k12|    +---+---+---+---+---+
+---+---+---+---+---+  * +---+---+---+ =  |   |   |   |   |   |
| k | l | m | n | o |    |k20|k21|k22|    +---+---+---+---+---+
+---+---+---+---+---+    +---+---+---+
| p | q | r | s | t |
+---+---+---+---+---+

O = a*k00 + b*k01 + c*k02 + f*k10 + g*k11 + h*k12 + k*k20 + l*k21 + m*k22
```

### Boundary Handling

At image edges, the kernel extends beyond the image boundary. Common strategies:

| Method | Description | Used Here |
|--------|-------------|-----------|
| Zero padding | Treat out-of-bounds as 0 | Yes |
| Replicate | Extend edge pixels | No |
| Mirror | Reflect across edge | No |

We use zero padding for simplicity and to avoid artifacts at boundaries.

## Sobel Edge Detection

### Theory

Edge detection identifies regions of rapid intensity change. The Sobel operator approximates the gradient of the image intensity function.

### Gradient Calculation

The gradient of an image `I(x,y)` is a vector:

```
nabla I = [ dI/dx ]
          [ dI/dy ]
```

Where:
- `dI/dx` = horizontal gradient (vertical edges)
- `dI/dy` = vertical gradient (horizontal edges)

### Sobel Kernels

The Sobel operator uses two 3x3 kernels to estimate gradients:

**Horizontal Gradient (Gx):**
```
     [-1  0  +1]
Gx = [-2  0  +2]
     [-1  0  +1]
```

**Vertical Gradient (Gy):**
```
     [-1  -2  -1]
Gy = [ 0   0   0]
     [+1  +2  +1]
```

### Gradient Magnitude

The edge strength is the gradient magnitude:

**Exact formula:**
```
|G| = sqrt(Gx^2 + Gy^2)
```

**Approximation used in hardware:**
```
|G| = |Gx| + |Gy|
```

The approximation avoids expensive square root computation while providing visually similar results. Maximum error is at 45-degree angles where the approximation overestimates by factor of sqrt(2).

### Why Sobel Works

The kernel structure provides:
1. **Smoothing** in one direction (the 1-2-1 weights)
2. **Differentiation** in the perpendicular direction (the -1, 0, +1 pattern)

This combination reduces noise sensitivity compared to simple gradient masks.

## Gaussian Blur

### Theory

Gaussian blur is a smoothing filter that reduces image noise and detail. It convolves the image with a Gaussian function.

### Gaussian Function

The 2D Gaussian function:

```
G(x,y) = (1 / 2*pi*sigma^2) * exp(-(x^2 + y^2) / (2*sigma^2))
```

Where `sigma` (standard deviation) controls the blur amount.

### Discrete Approximation

For a 3x3 kernel with sigma = 0.85:

```
          [1  2  1]
G_3x3 =   [2  4  2] * (1/16)
          [1  2  1]
```

The division by 16 normalizes the kernel (sum of coefficients = 1), preserving overall image brightness.

### Properties

1. **Separable:** Can be decomposed into two 1D convolutions
   ```
   G_3x3 = [1 2 1]^T * [1 2 1] / 16
   ```

2. **Symmetric:** Same result regardless of application direction

3. **Low-pass:** Removes high-frequency components (edges, noise)

### Implementation Efficiency

In the FPGA implementation:
- Kernel coefficients are integer (1, 2, 4)
- Division by 16 is a 4-bit right shift
- No floating-point hardware required

## Fixed-Point Arithmetic

### Q8.8 Format

The design uses Q8.8 fixed-point representation:

```
|  8 bits integer  |  8 bits fraction  |
+------------------+-------------------+
|    XXXXXXXX      |     XXXXXXXX      |
        |                   |
     0-255              0.00-0.996
```

**Range:** -128.0 to 127.996 (signed) or 0 to 255.996 (unsigned)
**Resolution:** 1/256 = 0.00390625

### Why Fixed-Point?

| Aspect | Fixed-Point | Floating-Point |
|--------|-------------|----------------|
| Hardware cost | Low (simple adders/multipliers) | High (complex units) |
| Speed | Fast (1-2 cycles) | Slower (multiple cycles) |
| Precision | Limited but sufficient | Higher than needed |
| Power | Low | Higher |

For 8-bit image processing, Q8.8 provides more than adequate precision while minimizing hardware resources.

### Multiplication

Multiplying two Q8.8 numbers produces a Q16.16 result. We truncate to Q8.8 after accumulation:

```
A (Q8.8) * B (Q8.8) = C (Q16.16)
C >> 8 = Result (Q8.8)
```

### Saturation

After convolution, values may exceed the 8-bit output range. Saturation clamps the result:

```
if (result > 255) result = 255;
if (result < 0)   result = 0;
```

## Line Buffer Architecture

### Problem

2D convolution requires accessing a 3x3 neighborhood around each pixel. In raster-scan order, we need pixels from:
- Current row
- Previous row
- Two rows back

### Solution: Circular Buffer

Three FIFO buffers, each storing one row of pixels:

```
Time T (processing pixel at row R, column C):

Buffer 0: [row R-2] ----+
Buffer 1: [row R-1] ----+---> 3x3 window
Buffer 2: [row R]   ----+
```

As each row completes, buffers rotate:
```
Time T+1 (next row):
Buffer 0: [row R-1] (was Buffer 1)
Buffer 1: [row R]   (was Buffer 2)
Buffer 2: [row R+1] (new data)
```

### Memory Efficiency

| Approach | Memory Required |
|----------|-----------------|
| Store entire image | 640 x 480 = 307,200 bytes |
| Line buffers | 640 x 3 = 1,920 bytes |

**Reduction: 160x less memory**

## Pipelining

### Concept

Pipelining divides processing into stages that operate concurrently:

```
Time    Stage1   Stage2   Stage3   Stage4
  0     Pixel_0    -        -        -
  1     Pixel_1  Pixel_0    -        -
  2     Pixel_2  Pixel_1  Pixel_0    -
  3     Pixel_3  Pixel_2  Pixel_1  Pixel_0  <- First output
  4     Pixel_4  Pixel_3  Pixel_2  Pixel_1
  ...
```

### Throughput vs Latency

- **Latency:** 7 cycles (time for one pixel through pipeline)
- **Throughput:** 1 pixel/cycle (after pipeline fills)

For 640x480 image:
- Initial latency: 1,287 cycles (7 + 2 rows of fill)
- Processing: 307,200 cycles
- **Effective rate:** 0.89 ms per frame

### Analogy

Think of it like an assembly line - each station does one task. The first car takes time to go through all stations, but after that, one car rolls off per station cycle time.

## Summary

| Operation | Kernel | Purpose | Hardware Benefit |
|-----------|--------|---------|------------------|
| Sobel Gx | 3x3 | Horizontal gradient | Parallel multiplication |
| Sobel Gy | 3x3 | Vertical gradient | Shared with Gx |
| Gaussian | 3x3 | Smoothing | Integer coefficients |

The mathematical simplicity of 3x3 convolution, combined with fixed-point arithmetic and line buffer architecture, enables efficient real-time processing on modest FPGA hardware.

---

*Author: Zeke Mohammed*
*References: Gonzalez & Woods, "Digital Image Processing" 4th Ed.*
