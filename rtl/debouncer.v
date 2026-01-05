/**
 * Button Debouncer Module
 *
 * Author: Zeke Mohammed
 * Date: July 2025
 *
 * Description:
 *   Debounces mechanical button inputs using timer-based filtering.
 *   Eliminates contact bounce noise from pushbuttons.
 *
 * Algorithm:
 *   - Synchronize input to clock domain (2-stage)
 *   - Wait for stable state for specified time before changing output
 *   - Default debounce time: 20ms (typ. button bounce is 5-10ms)
 *
 * Parameters:
 *   - DEBOUNCE_TIME_MS: Debounce time in milliseconds
 *   - CLOCK_FREQ_HZ: System clock frequency (default 100MHz)
 */

module debouncer #(
    parameter DEBOUNCE_TIME_MS = 20,      // Debounce time in ms
    parameter CLOCK_FREQ_HZ = 100_000_000 // Clock frequency in Hz
)(
    input  wire clk,
    input  wire reset,
    input  wire btn_in,      // Raw button input (active high)
    output reg  btn_out      // Debounced output
);

    // ========================================================================
    // Synchronizer (2-stage for metastability)
    // ========================================================================

    reg btn_sync1, btn_sync2;

    always @(posedge clk) begin
        if (reset) begin
            btn_sync1 <= 1'b0;
            btn_sync2 <= 1'b0;
        end else begin
            btn_sync1 <= btn_in;
            btn_sync2 <= btn_sync1;
        end
    end

    // ========================================================================
    // Debounce Counter
    // ========================================================================

    // Calculate counter max value for desired debounce time
    // Counter ticks = (DEBOUNCE_TIME_MS / 1000) × CLOCK_FREQ_HZ
    localparam COUNTER_MAX = (DEBOUNCE_TIME_MS * (CLOCK_FREQ_HZ / 1000)) - 1;
    localparam COUNTER_BITS = $clog2(COUNTER_MAX + 1);

    reg [COUNTER_BITS-1:0] counter;
    reg btn_stable;

    always @(posedge clk) begin
        if (reset) begin
            counter <= 0;
            btn_stable <= 1'b0;
            btn_out <= 1'b0;
        end else begin
            // Check if input matches current output
            if (btn_sync2 == btn_out) begin
                // Input stable - reset counter
                counter <= 0;
                btn_stable <= 1'b0;
            end else begin
                // Input different from output - count
                if (counter == COUNTER_MAX) begin
                    // Waited long enough - change output
                    btn_out <= btn_sync2;
                    counter <= 0;
                    btn_stable <= 1'b1;
                end else begin
                    counter <= counter + 1'b1;
                    btn_stable <= 1'b0;
                end
            end
        end
    end

endmodule
