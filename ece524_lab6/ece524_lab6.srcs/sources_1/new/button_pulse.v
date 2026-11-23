`timescale 1ns / 1ps
module button_pulse #(
    parameter integer DEBOUNCE_CYCLES = 1000000
)(
    input wire clk, button,
    output reg pulse = 1'b0
);
    localparam integer WIDTH = (DEBOUNCE_CYCLES <= 1) ? 1 : $clog2(DEBOUNCE_CYCLES);
    (* ASYNC_REG = "TRUE" *) reg sync_meta = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg sync_value = 1'b0;
    reg stable = 1'b0;
    localparam integer LAST_COUNT = DEBOUNCE_CYCLES-1;
    reg [WIDTH-1:0] count = 0;
    reg pressed = 1'b0;
    always @(posedge clk) begin
        sync_meta <= button;
        sync_value <= sync_meta;
        pressed <= 1'b0;
        if (sync_value == stable) count <= 0;
        else if (count == LAST_COUNT[WIDTH-1:0]) begin
            count <= 0;
            stable <= sync_value;
            pressed <= sync_value;
        end else count <= count + 1'b1;
    end
    // Match the handout: one full-clock pulse starting at a falling edge.
    always @(negedge clk) pulse <= pressed;
endmodule
