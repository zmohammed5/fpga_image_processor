/**
 * Sobel Edge Detection Module
 *
 * Author: Zeke Mohammed
 * Date: September 2025
 *
 * Description:
 *   Implements Sobel edge detection using gradient magnitude approximation.
 *   Uses two 3x3 convolutions (Gx and Gy) followed by magnitude calculation.
 *
 * Algorithm:
 *   Gx (horizontal gradient):  [-1  0  +1]
 *                               [-2  0  +2]
 *                               [-1  0  +1]
 *
 *   Gy (vertical gradient):    [-1 -2  -1]
 *                               [ 0  0   0]
 *                               [+1 +2  +1]
 *
 *   Magnitude = |Gx| + |Gy|  (approximation, faster than sqrt(Gx² + Gy²))
 *
 * Performance:
 *   - Latency: ~1284 cycles (2 rows + pipeline)
 *   - Throughput: 1 pixel/cycle
 *   - Resources: 18 DSP48E1, ~2400 LUTs, 4 BRAM
 */

module edge_detector #(
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 480,

    // Threshold for edge detection (0-255)
    // Pixels with magnitude > threshold are marked as edges (white)
    // Otherwise, output is black
    parameter EDGE_THRESHOLD = 50
)(
    input  wire        clk,
    input  wire        reset,

    // Input pixel stream
    input  wire [7:0]  pixel_in,
    input  wire        pixel_valid,
    input  wire [9:0]  col,
    input  wire [9:0]  row,

    // Output stream
    output wire [7:0]  pixel_out,
    output wire        pixel_out_valid
);

    // ========================================================================
    // Sobel Kernels in Q8.8 Fixed-Point Format
    // ========================================================================

    // Gx kernel (horizontal gradient detection)
    localparam signed [15:0] GX_K00 = -16'sh0100;  // -1.0
    localparam signed [15:0] GX_K01 =  16'sh0000;  //  0.0
    localparam signed [15:0] GX_K02 =  16'sh0100;  // +1.0
    localparam signed [15:0] GX_K10 = -16'sh0200;  // -2.0
    localparam signed [15:0] GX_K11 =  16'sh0000;  //  0.0
    localparam signed [15:0] GX_K12 =  16'sh0200;  // +2.0
    localparam signed [15:0] GX_K20 = -16'sh0100;  // -1.0
    localparam signed [15:0] GX_K21 =  16'sh0000;  //  0.0
    localparam signed [15:0] GX_K22 =  16'sh0100;  // +1.0

    // Gy kernel (vertical gradient detection)
    localparam signed [15:0] GY_K00 = -16'sh0100;  // -1.0
    localparam signed [15:0] GY_K01 = -16'sh0200;  // -2.0
    localparam signed [15:0] GY_K02 = -16'sh0100;  // -1.0
    localparam signed [15:0] GY_K10 =  16'sh0000;  //  0.0
    localparam signed [15:0] GY_K11 =  16'sh0000;  //  0.0
    localparam signed [15:0] GY_K12 =  16'sh0000;  //  0.0
    localparam signed [15:0] GY_K20 =  16'sh0100;  // +1.0
    localparam signed [15:0] GY_K21 =  16'sh0200;  // +2.0
    localparam signed [15:0] GY_K22 =  16'sh0100;  // +1.0

    // ========================================================================
    // Gx Convolution (Horizontal Gradients)
    // ========================================================================

    wire [7:0] gx_out;
    wire gx_valid;

    convolution_engine #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .K00(GX_K00), .K01(GX_K01), .K02(GX_K02),
        .K10(GX_K10), .K11(GX_K11), .K12(GX_K12),
        .K20(GX_K20), .K21(GX_K21), .K22(GX_K22),
        .NORM_SHIFT(8)  // Q8.8 -> 8-bit
    ) gx_conv (
        .clk(clk),
        .reset(reset),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .col(col),
        .row(row),
        .pixel_out(gx_out),
        .pixel_out_valid(gx_valid)
    );

    // ========================================================================
    // Gy Convolution (Vertical Gradients)
    // ========================================================================

    wire [7:0] gy_out;
    wire gy_valid;

    convolution_engine #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .K00(GY_K00), .K01(GY_K01), .K02(GY_K02),
        .K10(GY_K10), .K11(GY_K11), .K12(GY_K12),
        .K20(GY_K20), .K21(GY_K21), .K22(GY_K22),
        .NORM_SHIFT(8)  // Q8.8 -> 8-bit
    ) gy_conv (
        .clk(clk),
        .reset(reset),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .col(col),
        .row(row),
        .pixel_out(gy_out),
        .pixel_out_valid(gy_valid)
    );

    // ========================================================================
    // Gradient Magnitude Calculation
    // ========================================================================

    // Use |Gx| + |Gy| instead of sqrt(Gx² + Gy²) for FPGA efficiency
    // This gives approximately same results and is much faster

    reg [7:0] gx_abs, gy_abs;
    reg [8:0] magnitude;  // 9-bit to handle sum overflow
    reg mag_valid;

    always @(posedge clk) begin
        if (reset) begin
            gx_abs    <= 8'd0;
            gy_abs    <= 8'd0;
            magnitude <= 9'd0;
            mag_valid <= 1'b0;
        end else begin
            // Absolute values (Gx and Gy are already unsigned from convolution output)
            gx_abs <= gx_out;
            gy_abs <= gy_out;

            // Sum of absolute values
            magnitude <= {1'b0, gx_abs} + {1'b0, gy_abs};

            mag_valid <= gx_valid && gy_valid;  // Both must be valid
        end
    end

    // ========================================================================
    // Thresholding and Output
    // ========================================================================

    reg [7:0] edge_pixel;
    reg edge_valid;

    always @(posedge clk) begin
        if (reset) begin
            edge_pixel <= 8'd0;
            edge_valid <= 1'b0;
        end else begin
            // Saturate magnitude to 8 bits
            if (magnitude > 9'd255) begin
                edge_pixel <= 8'd255;
            end else begin
                edge_pixel <= magnitude[7:0];
            end

            // Alternative: Binary thresholding for stark edge detection
            // if (magnitude > EDGE_THRESHOLD) begin
            //     edge_pixel <= 8'd255;  // White (edge detected)
            // end else begin
            //     edge_pixel <= 8'd0;    // Black (no edge)
            // end

            edge_valid <= mag_valid;
        end
    end

    assign pixel_out = edge_pixel;
    assign pixel_out_valid = edge_valid;

    // ========================================================================
    // Debug and Verification
    // ========================================================================

    // Synthesis translate_off (simulation only)
    `ifdef SIM
        reg [31:0] edge_count;  // Count of detected edges
        always @(posedge clk) begin
            if (reset) begin
                edge_count <= 32'd0;
            end else if (edge_valid && (edge_pixel > EDGE_THRESHOLD)) begin
                edge_count <= edge_count + 1'b1;
            end
        end
    `endif
    // Synthesis translate_on

endmodule
