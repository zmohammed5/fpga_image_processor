/**
 * VGA Controller - 640x480 @ 60Hz
 *
 * Author: Zeke Mohammed
 * Date: July 2025
 *
 * Description:
 *   Generates VGA timing signals for 640x480 resolution at 60Hz refresh rate.
 *   Pixel clock: 25.175 MHz (actual: 25.000 MHz is close enough)
 *
 * VGA 640x480 @ 60Hz Timing:
 *   Horizontal:
 *     Visible area:  640 pixels
 *     Front porch:    16 pixels
 *     Sync pulse:     96 pixels
 *     Back porch:     48 pixels
 *     Total:         800 pixels
 *
 *   Vertical:
 *     Visible area:  480 lines
 *     Front porch:     10 lines
 *     Sync pulse:       2 lines
 *     Back porch:      33 lines
 *     Total:          525 lines
 *
 * Resources:
 *   - ~80 LUTs
 *   - 2 counters (10-bit each)
 */

module vga_controller (
    input  wire        clk_vga,          // 25.175 MHz pixel clock
    input  wire        reset,

    output reg  [9:0]  h_count,          // Horizontal pixel counter (0-799)
    output reg  [9:0]  v_count,          // Vertical line counter (0-524)
    output wire        hsync,            // Horizontal sync (active low)
    output wire        vsync,            // Vertical sync (active low)
    output wire        display_enable    // High during visible area
);

    // ========================================================================
    // VGA Timing Parameters
    // ========================================================================

    // Horizontal timing (in pixels)
    localparam H_VISIBLE_AREA = 640;
    localparam H_FRONT_PORCH  = 16;
    localparam H_SYNC_PULSE   = 96;
    localparam H_BACK_PORCH   = 48;
    localparam H_TOTAL        = 800;  // 640 + 16 + 96 + 48

    // Horizontal timing boundaries
    localparam H_SYNC_START = H_VISIBLE_AREA + H_FRONT_PORCH;              // 656
    localparam H_SYNC_END   = H_VISIBLE_AREA + H_FRONT_PORCH + H_SYNC_PULSE; // 752
    localparam H_MAX        = H_TOTAL - 1;                                  // 799

    // Vertical timing (in lines)
    localparam V_VISIBLE_AREA = 480;
    localparam V_FRONT_PORCH  = 10;
    localparam V_SYNC_PULSE   = 2;
    localparam V_BACK_PORCH   = 33;
    localparam V_TOTAL        = 525;  // 480 + 10 + 2 + 33

    // Vertical timing boundaries
    localparam V_SYNC_START = V_VISIBLE_AREA + V_FRONT_PORCH;              // 490
    localparam V_SYNC_END   = V_VISIBLE_AREA + V_FRONT_PORCH + V_SYNC_PULSE; // 492
    localparam V_MAX        = V_TOTAL - 1;                                  // 524

    // ========================================================================
    // Horizontal Counter
    // ========================================================================

    always @(posedge clk_vga) begin
        if (reset) begin
            h_count <= 10'd0;
        end else begin
            if (h_count == H_MAX) begin
                h_count <= 10'd0;
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    // ========================================================================
    // Vertical Counter
    // ========================================================================

    always @(posedge clk_vga) begin
        if (reset) begin
            v_count <= 10'd0;
        end else begin
            // Increment vertical counter at end of each horizontal line
            if (h_count == H_MAX) begin
                if (v_count == V_MAX) begin
                    v_count <= 10'd0;
                end else begin
                    v_count <= v_count + 1'b1;
                end
            end
        end
    end

    // ========================================================================
    // Sync Signal Generation
    // ========================================================================

    // Horizontal sync (active low)
    assign hsync = !((h_count >= H_SYNC_START) && (h_count < H_SYNC_END));

    // Vertical sync (active low)
    assign vsync = !((v_count >= V_SYNC_START) && (v_count < V_SYNC_END));

    // ========================================================================
    // Display Enable Signal
    // ========================================================================

    // High only during visible area (not during blanking intervals)
    assign display_enable = (h_count < H_VISIBLE_AREA) && (v_count < V_VISIBLE_AREA);

    // ========================================================================
    // Frame and Line Pulse Generation (for debugging/sync)
    // ========================================================================

    wire frame_pulse;  // One clock pulse at start of each frame
    wire line_pulse;   // One clock pulse at start of each line

    assign frame_pulse = (h_count == 0) && (v_count == 0);
    assign line_pulse  = (h_count == 0);

endmodule
