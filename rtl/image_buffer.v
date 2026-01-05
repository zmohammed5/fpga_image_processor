/**
 * Dual-Port Image Buffer
 *
 * Author: Zeke Mohammed
 * Date: August 2025
 *
 * Description:
 *   Frame buffer for storing 640x480 grayscale image.
 *   Implemented using Xilinx block RAM (BRAM) primitives.
 *
 * Memory Organization:
 *   - Total pixels: 640 × 480 = 307,200 pixels
 *   - Bits per pixel: 8 (grayscale)
 *   - Total memory: 307,200 bytes = 2,457,600 bits ≈ 2.4 Mb
 *   - Implementation: 8 BRAM tiles (each 36 Kb)
 *
 * Port A: Write interface (UART image upload)
 * Port B: Read interface (VGA display / processing)
 *
 * Resources:
 *   - 8 BRAM tiles (36Kb each)
 *   - ~200 LUTs for address generation
 */

module image_buffer (
    // Port A: Write (UART upload)
    input  wire        clk_wr,
    input  wire        we,              // Write enable
    input  wire [18:0] addr_wr,         // Write address (0 to 307,199)
    input  wire [7:0]  data_in,         // Pixel data to write

    // Port B: Read (VGA/processing)
    input  wire        clk_rd,
    input  wire [18:0] addr_rd,         // Read address
    output reg  [7:0]  data_out         // Pixel data read
);

    // ========================================================================
    // Memory Array
    // ========================================================================

    // Block RAM array: 307,200 × 8 bits
    (* ram_style = "block" *)
    reg [7:0] mem [0:307199];

    // Initialize memory to black (optional, for simulation)
    integer i;
    initial begin
        for (i = 0; i < 307200; i = i + 1) begin
            mem[i] = 8'd0;
        end
    end

    // ========================================================================
    // Port A: Write Operation
    // ========================================================================

    always @(posedge clk_wr) begin
        if (we) begin
            mem[addr_wr] <= data_in;
        end
    end

    // ========================================================================
    // Port B: Read Operation (with 1-cycle latency for BRAM)
    // ========================================================================

    always @(posedge clk_rd) begin
        data_out <= mem[addr_rd];
    end

    // ========================================================================
    // Synthesis Attributes
    // ========================================================================

    // Force use of block RAM (not distributed RAM)
    // Xilinx-specific attribute
    (* ram_style = "block" *) reg [7:0] mem_bram [0:307199];

endmodule
