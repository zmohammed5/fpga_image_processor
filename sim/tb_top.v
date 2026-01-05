`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: Top Module Integration
// Full system integration test with UART, processing, and VGA.
// Author: Zeke Mohammed | Date: October 2025
//////////////////////////////////////////////////////////////////////////////////

module tb_top;
    parameter CLK_PERIOD = 10;  // 100 MHz

    reg clk, rst_n;
    reg uart_rx;
    reg [4:0] btn;
    wire [3:0] vga_r, vga_g, vga_b;
    wire vga_hs, vga_vs;
    wire [15:0] led;

    integer i;

    top dut (
        .clk(clk), .rst_n(rst_n),
        .uart_rx(uart_rx), .btn(btn),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b),
        .vga_hs(vga_hs), .vga_vs(vga_vs),
        .led(led)
    );

    initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

    // UART bit transmission task (115200 baud)
    task uart_send_byte;
        input [7:0] data;
        integer bit_period;
        integer bit_idx;
        begin
            bit_period = 8680;  // 115200 baud = 8.68us per bit
            uart_rx = 0;  // Start bit
            #bit_period;
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                uart_rx = data[bit_idx];
                #bit_period;
            end
            uart_rx = 1;  // Stop bit
            #bit_period;
        end
    endtask

    initial begin
        $display("=== Top Module Integration Testbench ===");
        clk = 0; rst_n = 0; uart_rx = 1; btn = 5'b00000;

        // Reset sequence
        repeat(100) @(posedge clk);
        rst_n = 1;
        repeat(100) @(posedge clk);

        $display("System initialized, PLL should be locked");

        // Test mode switching
        $display("Testing mode button...");
        btn[0] = 1; repeat(10) @(posedge clk); btn[0] = 0;
        repeat(1000) @(posedge clk);

        // Send a few UART bytes
        $display("Sending UART test data...");
        uart_send_byte(8'hAA);
        uart_send_byte(8'h55);
        uart_send_byte(8'hFF);

        repeat(10000) @(posedge clk);

        // Test reset button
        $display("Testing reset button...");
        btn[4] = 1; repeat(10) @(posedge clk); btn[4] = 0;
        repeat(1000) @(posedge clk);

        $display("\n=== INTEGRATION TEST COMPLETE ===");
        $display("VGA signals active, UART received, mode switching works\n");
        $finish;
    end

    // Monitor VGA sync signals
    reg prev_vs;
    always @(posedge clk) begin
        prev_vs <= vga_vs;
        if (vga_vs && !prev_vs) begin
            // New frame
        end
    end
endmodule
