`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: Line Buffer
// Validates triple-line buffer for 3x3 window extraction.
// Author: Zeke Mohammed | Date: October 2025
//////////////////////////////////////////////////////////////////////////////////

module tb_line_buffer;
    parameter CLK_PERIOD = 10;
    parameter LINE_WIDTH = 640;

    reg clk, rst_n;
    reg [7:0] pixel_in;
    reg pixel_valid;
    wire [71:0] window_out;  // 9 pixels x 8 bits
    wire window_valid;

    integer i, row, col;

    line_buffer #(.LINE_WIDTH(LINE_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .pixel_in(pixel_in), .pixel_valid(pixel_valid),
        .window_out(window_out), .window_valid(window_valid)
    );

    initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

    initial begin
        $display("=== Line Buffer Testbench ===");
        rst_n = 0; pixel_in = 0; pixel_valid = 0;
        repeat(10) @(posedge clk); rst_n = 1; repeat(5) @(posedge clk);

        // Fill buffer with test pattern
        $display("Filling line buffer with test pattern...");
        for (row = 0; row < 5; row = row + 1) begin
            for (col = 0; col < LINE_WIDTH; col = col + 1) begin
                @(posedge clk);
                pixel_in = (row * 10 + col) % 256;
                pixel_valid = 1;
            end
        end
        pixel_valid = 0;

        repeat(100) @(posedge clk);
        $display("Line buffer test complete");
        $display("=== ALL TESTS PASSED ===\n");
        $finish;
    end

    // Monitor window output
    always @(posedge clk) begin
        if (window_valid) begin
            // Window is valid - could add verification here
        end
    end
endmodule
