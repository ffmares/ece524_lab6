`timescale 1ns / 1ps
module main_fsm #(
    parameter integer DEBOUNCE_CYCLES = 1000000, // 10 ms at 100 MHz
    parameter integer BLINK_HALF_CYCLES = 50000000 // 1 Hz blink
)(
    input wire clk,
    input wire btn_n, btn_e, btn_s, btn_w,
    output wire [7:0] led,
    output wire unlock, alarm
);
    wire reset_pulse;
    wire [2:0] key;
    wire [3:0] state_number;
    
    button_pulse #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) north(clk, btn_n, reset_pulse);
    button_pulse #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) east(clk, btn_e, key[2]);
    button_pulse #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) south(clk, btn_s, key[1]);
    button_pulse #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) west(clk, btn_w, key[0]);
    lock_fsm controller(clk, reset_pulse, key, unlock, alarm, state_number);
    localparam integer WIDTH = (BLINK_HALF_CYCLES <= 1) ? 1 : $clog2(BLINK_HALF_CYCLES);
    localparam integer LAST_COUNT = BLINK_HALF_CYCLES-1;
    reg [WIDTH-1:0] blink_count = 0;
    reg blink_on = 1'b1;
    
    // Control logic
    always @(posedge clk) begin
        if (!alarm) begin
            blink_count <= 0;
            blink_on <= 1'b1;
        end else if (blink_count == LAST_COUNT[WIDTH-1:0]) begin
            blink_count <= 0;
            blink_on <= !blink_on;
        end else blink_count <= blink_count + 1'b1;
    end
    assign led = unlock ? 8'h55 : // ASCII U
                 alarm ? (blink_on ? 8'h41 : 8'h00) : // ASCII A
                 {4'b0000, state_number};
endmodule
