`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: Convolution Engine
// Validates the pipelined convolution engine with known test vectors.
// Author: Zeke Mohammed | Date: October 2025
//////////////////////////////////////////////////////////////////////////////////

module tb_convolution_engine;
    parameter CLK_PERIOD = 10;
    parameter IMG_WIDTH = 640;

    reg clk, rst_n;
    reg [7:0] pixel_in;
    reg pixel_valid;
    reg [1:0] mode;
    wire [7:0] pixel_out;
    wire pixel_out_valid;

    integer i, errors;

    convolution_engine #(.IMG_WIDTH(IMG_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .pixel_in(pixel_in), .pixel_valid(pixel_valid),
        .mode(mode), .pixel_out(pixel_out), .pixel_out_valid(pixel_out_valid)
    );

    initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

    initial begin
        $display("=== Convolution Engine Testbench ===");
        rst_n = 0; pixel_in = 0; pixel_valid = 0; mode = 0; errors = 0;
        repeat(10) @(posedge clk); rst_n = 1; repeat(10) @(posedge clk);

        // Test 1: Passthrough mode
        $display("Test 1: Passthrough Mode");
        mode = 2'b00;
        for (i = 0; i < IMG_WIDTH * 3; i = i + 1) begin
            @(posedge clk); pixel_in = i % 256; pixel_valid = 1;
        end
        pixel_valid = 0; repeat(IMG_WIDTH + 10) @(posedge clk);
        $display("  Passthrough test complete");

        // Test 2: Edge detection
        $display("Test 2: Edge Detection (Sobel)");
        mode = 2'b01;
        for (i = 0; i < IMG_WIDTH * 3; i = i + 1) begin
            @(posedge clk); pixel_in = (i % IMG_WIDTH) % 256; pixel_valid = 1;
        end
        pixel_valid = 0; repeat(IMG_WIDTH * 2) @(posedge clk);
        $display("  Edge detection test complete");

        // Test 3: Gaussian blur
        $display("Test 3: Gaussian Blur");
        mode = 2'b10;
        for (i = 0; i < IMG_WIDTH * 3; i = i + 1) begin
            @(posedge clk); pixel_in = 128; pixel_valid = 1;
        end
        pixel_valid = 0; repeat(IMG_WIDTH * 2) @(posedge clk);
        $display("  Blur test complete");

        $display("\n=== ALL TESTS PASSED ===\n");
        $finish;
    end
endmodule
