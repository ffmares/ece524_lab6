`timescale 1ns / 1ps
// Moore FSM. key = {E,S,W}, one clock pulse per accepted press.
module lock_fsm (
    input wire clk, reset,
    input wire [2:0] key,
    output wire unlock, alarm,
    output wire [3:0] state_number
);
    localparam [3:0] RESET=0, S=1, SW=2, SWE=3,
        BAD1=4, BAD2=5, BAD2E=6, BAD3=7, BAD3E=8,
        OPEN=9, ALARM=10, ALARM_W=11;
    reg [3:0] state = RESET;
    reg [3:0] next_state;
    assign state_number = state;
    assign unlock = (state == OPEN);
    assign alarm = (state == ALARM || state == ALARM_W);
    always @* begin
        next_state = state;
        // Ignore simultaneous keys: only a single, one-hot event is valid.
        if (key == 3'b100 || key == 3'b010 || key == 3'b001) begin
            case (state)
                RESET: next_state = (key == 3'b010) ? S : BAD1;
                S: next_state = (key == 3'b001) ? SW :
                                (key == 3'b100) ? BAD2E : BAD2;
                SW: next_state = (key == 3'b100) ? SWE : BAD3;
                SWE: next_state = (key == 3'b001) ? OPEN :
                                  (key == 3'b100) ? RESET : ALARM;
                // E-E beginning in RESET is not a reset command (lab exception).
                BAD1: next_state = (key == 3'b100) ? BAD2E : BAD2;
                BAD2: next_state = (key == 3'b100) ? BAD3E : BAD3;
                BAD2E: next_state = (key == 3'b100) ? RESET : BAD3;
                // A fourth wrong W also starts recovery (handout W-S-S-W-E).
                BAD3: next_state = (key == 3'b001) ? ALARM_W : ALARM;
                BAD3E: next_state = (key == 3'b100) ? RESET :
                                    (key == 3'b001) ? ALARM_W : ALARM;
                OPEN: next_state = RESET;
                ALARM: next_state = (key == 3'b001) ? ALARM_W : ALARM;
                ALARM_W: next_state = (key == 3'b100) ? RESET :
                                      (key == 3'b001) ? ALARM_W : ALARM;
                default: next_state = RESET;
            endcase
        end
    end
    always @(posedge clk) begin
        // The administrator W-E sequence is the only alarm exit.
        if (reset && !alarm) state <= RESET;
        else state <= next_state;
    end
endmodule
