/**
 * Triple Line Buffer for 2D Convolution
 *
 * Author: Zeke Mohammed
 * Date: August 2025
 *
 * Description:
 *   Circular buffer storing 3 lines of image data for sliding window convolution.
 *   Optimized for Xilinx block RAM (BRAM) primitives.
 *
 * Operation:
 *   - Stores the last 3 rows of pixels
 *   - As new pixels arrive, oldest line is overwritten
 *   - Outputs 3 pixels (one from each line) simultaneously
 *   - Enables 3x3 window extraction for convolution
 *
 * Memory Organization:
 *   Line 0: BRAM 0 (oldest)
 *   Line 1: BRAM 1 (middle)
 *   Line 2: Current pixel stream (newest, not stored yet)
 *
 * Resources:
 *   - 2 BRAM tiles (36Kb each)
 *   - ~100 LUTs for control logic
 */

module line_buffer #(
    parameter IMAGE_WIDTH = 640
)(
    input  wire        clk,
    input  wire        reset,

    // Input pixel stream
    input  wire [7:0]  pixel_in,
    input  wire        pixel_valid,

    // Outputs: 3 vertically aligned pixels
    output wire [7:0]  line0_out,       // Oldest line (top of 3x3 window)
    output wire [7:0]  line1_out,       // Middle line
    output wire [7:0]  line2_out        // Current line (bottom of 3x3 window)
);

    // ========================================================================
    // Internal Line Buffers (Dual-Port Block RAM)
    // ========================================================================

    // BRAM for line 0 (oldest)
    reg [7:0] line_ram_0 [0:IMAGE_WIDTH-1];
    reg [9:0] wr_addr_0;
    reg [9:0] rd_addr_0;
    reg [7:0] rd_data_0;

    // BRAM for line 1 (middle)
    reg [7:0] line_ram_1 [0:IMAGE_WIDTH-1];
    reg [9:0] wr_addr_1;
    reg [9:0] rd_addr_1;
    reg [7:0] rd_data_1;

    // Current input goes directly to line2_out (no storage needed)
    reg [7:0] line2_reg;

    // ========================================================================
    // Write/Read Address Generation
    // ========================================================================

    reg [9:0] pixel_count;          // Current pixel in row (0-639)
    reg [9:0] row_count;            // Current row number
    reg [1:0] active_buffer;        // Which buffer is being written (0, 1, or current)

    always @(posedge clk) begin
        if (reset) begin
            pixel_count   <= 10'd0;
            row_count     <= 10'd0;
            active_buffer <= 2'd0;
            wr_addr_0     <= 10'd0;
            wr_addr_1     <= 10'd0;
            rd_addr_0     <= 10'd0;
            rd_addr_1     <= 10'd0;
            line2_reg     <= 8'd0;
        end else if (pixel_valid) begin
            // Track position in image
            if (pixel_count == IMAGE_WIDTH - 1) begin
                pixel_count <= 10'd0;
                row_count   <= row_count + 1'b1;

                // Rotate buffers every row
                active_buffer <= (active_buffer == 2'd1) ? 2'd0 : active_buffer + 1'b1;
            end else begin
                pixel_count <= pixel_count + 1'b1;
            end

            // Write to appropriate buffer based on row
            case (row_count[1:0])
                2'd0: wr_addr_0 <= pixel_count;  // Row 0: write to buffer 0
                2'd1: wr_addr_1 <= pixel_count;  // Row 1: write to buffer 1
                2'd2: wr_addr_0 <= pixel_count;  // Row 2: overwrite buffer 0
                2'd3: wr_addr_1 <= pixel_count;  // Row 3: overwrite buffer 1
            endcase

            // Read address is one pixel ahead (for next cycle)
            if (pixel_count < IMAGE_WIDTH - 1) begin
                rd_addr_0 <= pixel_count + 1'b1;
                rd_addr_1 <= pixel_count + 1'b1;
            end else begin
                rd_addr_0 <= 10'd0;  // Wrap to start of next line
                rd_addr_1 <= 10'd0;
            end

            // Current pixel (line 2)
            line2_reg <= pixel_in;
        end
    end

    // ========================================================================
    // BRAM Write Operations
    // ========================================================================

    always @(posedge clk) begin
        if (pixel_valid) begin
            // Write to buffer 0 on even rows (0, 2, 4, ...)
            if (row_count[0] == 1'b0) begin
                line_ram_0[wr_addr_0] <= pixel_in;
            end

            // Write to buffer 1 on odd rows (1, 3, 5, ...)
            if (row_count[0] == 1'b1) begin
                line_ram_1[wr_addr_1] <= pixel_in;
            end
        end
    end

    // ========================================================================
    // BRAM Read Operations (with 1-cycle latency)
    // ========================================================================

    always @(posedge clk) begin
        rd_data_0 <= line_ram_0[rd_addr_0];
        rd_data_1 <= line_ram_1[rd_addr_1];
    end

    // ========================================================================
    // Output Assignment Based on Current Row
    // ========================================================================

    // Determine which buffer contains which line based on row number
    reg [7:0] line0_mux, line1_mux, line2_mux;

    always @(*) begin
        case (row_count[1:0])
            2'd0: begin
                // Row 0: no valid lines yet (output zeros)
                line0_mux = 8'd0;
                line1_mux = 8'd0;
                line2_mux = line2_reg;
            end
            2'd1: begin
                // Row 1: only have 1 previous line
                line0_mux = 8'd0;
                line1_mux = rd_data_0;      // Previous row in buffer 0
                line2_mux = line2_reg;
            end
            2'd2: begin
                // Row 2: have 2 previous lines
                line0_mux = rd_data_0;      // Row 0 still in buffer 0
                line1_mux = rd_data_1;      // Row 1 in buffer 1
                line2_mux = line2_reg;
            end
            2'd3: begin
                // Row 3+: full 3-line window available
                line0_mux = rd_data_1;      // Oldest (row was in buffer 1)
                line1_mux = rd_data_0;      // Middle (row was in buffer 0)
                line2_mux = line2_reg;
            end
        endcase
    end

    assign line0_out = line0_mux;
    assign line1_out = line1_mux;
    assign line2_out = line2_mux;

    // ========================================================================
    // Synthesis Attributes for BRAM Inference
    // ========================================================================

    // Xilinx-specific attributes to ensure block RAM usage
    (* ram_style = "block" *) reg [7:0] line_ram_0_attr [0:IMAGE_WIDTH-1];
    (* ram_style = "block" *) reg [7:0] line_ram_1_attr [0:IMAGE_WIDTH-1];

endmodule
