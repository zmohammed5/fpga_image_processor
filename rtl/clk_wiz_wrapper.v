/**
 * Clock Wizard Wrapper
 *
 * Author: Zeke Mohammed
 * Date: July 2025
 *
 * Description:
 *   Wrapper for Xilinx Clock Wizard IP (clocking wizard).
 *   Generates required clocks from 100MHz input oscillator.
 *
 * Clock Outputs:
 *   - clk_vga: 25.175 MHz (VGA pixel clock for 640x480@60Hz)
 *   - clk_proc: 100 MHz (processing clock, same as input)
 *
 * Note:
 *   Actual implementation uses Xilinx MMCM (Mixed-Mode Clock Manager).
 *   For portability, this shows behavioral model.
 *   In real design, use Vivado Clock Wizard IP with these settings:
 *     - Input: 100 MHz
 *     - Output 1: 25.175 MHz (VGA)
 *     - Output 2: 100 MHz (Processing)
 */

module clk_wiz_wrapper (
    input  wire clk_in,        // 100 MHz input from crystal
    input  wire reset,         // Reset

    output wire clk_vga,       // 25.175 MHz VGA pixel clock
    output wire clk_proc,      // 100 MHz processing clock
    output wire locked         // PLL locked indicator
);

`ifdef XILINX_SIMULATOR
    // ========================================================================
    // Simulation Model (for testbenches)
    // ========================================================================

    reg [1:0] vga_clk_div;
    reg sim_locked;

    // Simple clock divider for simulation
    // 100 MHz / 4 = 25 MHz (close enough for simulation)
    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            vga_clk_div <= 2'b00;
            sim_locked <= 1'b0;
        end else begin
            vga_clk_div <= vga_clk_div + 1'b1;
            sim_locked <= 1'b1;  // Lock immediately in simulation
        end
    end

    assign clk_vga = vga_clk_div[1];  // Divide by 4
    assign clk_proc = clk_in;          // Pass through
    assign locked = sim_locked;

`else
    // ========================================================================
    // Synthesis Implementation (Xilinx MMCM/PLL)
    // ========================================================================

    /*
     * In actual synthesis, instantiate Xilinx Clock Wizard IP:
     *
     * clk_wiz_0 your_instance_name (
     *     .clk_in1(clk_in),
     *     .reset(reset),
     *     .clk_out1(clk_vga),   // 25.175 MHz
     *     .clk_out2(clk_proc),  // 100 MHz
     *     .locked(locked)
     * );
     *
     * Configuration settings in Vivado:
     *   - Primitive: MMCME2_ADV
     *   - Input frequency: 100 MHz
     *   - Output clk_out1: 25.175 MHz
     *     - Divide: Use M=63, D=10, O0=25 to get 25.2 MHz (close enough)
     *   - Output clk_out2: 100 MHz (CLKOUT1_DIVIDE = 10)
     *   - Enable locked output
     *   - Safe clock startup enabled
     */

    // For standalone synthesis without IP, use MMCM primitive directly
    wire clkfbout;
    wire clkfbout_buf;
    wire clk_vga_unbuf;
    wire clk_proc_unbuf;

    // MMCM instantiation for Artix-7
    MMCME2_ADV #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(10.0),          // VCO = 100 MHz × 10 = 1000 MHz
        .CLKFBOUT_PHASE(0.0),
        .CLKIN1_PERIOD(10.0),            // 100 MHz = 10 ns period
        .CLKOUT0_DIVIDE_F(39.75),        // 1000 / 39.75 ≈ 25.157 MHz
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),
        .CLKOUT1_DIVIDE(10),             // 1000 / 10 = 100 MHz
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT1_PHASE(0.0),
        .DIVCLK_DIVIDE(1),
        .REF_JITTER1(0.010),
        .STARTUP_WAIT("FALSE")
    ) mmcm_inst (
        .CLKFBOUT(clkfbout),
        .CLKFBOUTB(),
        .CLKOUT0(clk_vga_unbuf),
        .CLKOUT1(clk_proc_unbuf),
        .CLKOUT2(),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .CLKFBIN(clkfbout_buf),
        .CLKIN1(clk_in),
        .CLKIN2(1'b0),
        .CLKINSEL(1'b1),
        .DADDR(7'h0),
        .DCLK(1'b0),
        .DEN(1'b0),
        .DI(16'h0),
        .DWE(1'b0),
        .PSCLK(1'b0),
        .PSEN(1'b0),
        .PSINCDEC(1'b0),
        .PWRDWN(1'b0),
        .RST(reset),
        .LOCKED(locked)
    );

    // Buffer feedback clock
    BUFG clkf_buf (
        .I(clkfbout),
        .O(clkfbout_buf)
    );

    // Buffer output clocks
    BUFG clkvga_buf (
        .I(clk_vga_unbuf),
        .O(clk_vga)
    );

    BUFG clkproc_buf (
        .I(clk_proc_unbuf),
        .O(clk_proc)
    );

`endif

endmodule
