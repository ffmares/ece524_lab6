`timescale 1ns / 1ps
module tb_lab6;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 0;
    reg [2:0] key = 0;
    wire unlock, alarm;
    wire [3:0] state_number;
    lock_fsm core(clk, reset, key, unlock, alarm, state_number);
    reg n=0, e=0, s=0, w=0;
    wire [7:0] led;
    wire board_unlock, board_alarm;
    main_fsm #(.DEBOUNCE_CYCLES(4), .BLINK_HALF_CYCLES(20)) board(
        clk,n,e,s,w,led,board_unlock,board_alarm);
    integer count=0;
    bit correct=1, prev_e=0, alarm_w=0;
    integer mode=0; // independent behavioral model: locked, open, alarm
    integer checks=0;
    task tick;
        @(posedge clk); #1;
    endtask
    task model(input integer symbol);
        if (mode == 2) begin
            if (alarm_w && symbol == 0) begin
                mode=0; count=0; correct=1; prev_e=0;
            end
            alarm_w=(symbol==2);
        end else if (mode == 1) begin
            mode=0; count=0; correct=1; prev_e=0;
        end else if (prev_e && symbol==0) begin
            count=0; correct=1; prev_e=0;
        end else begin
            // Password symbols are S W E W. Reset pair must start outside RESET.
            prev_e=(symbol==0 && count!=0);
            case(count)
                0: correct=correct && symbol==1;
                1: correct=correct && symbol==2;
                2: correct=correct && symbol==0;
                3: correct=correct && symbol==2;
            endcase
            count=count+1;
            if(count==4) begin mode=correct ? 1 : 2; alarm_w=(symbol==2); end
        end
    endtask
    task press(input integer symbol);
        @(negedge clk); key=3'b100 >> symbol;
        model(symbol); tick();
        if(unlock !== (mode==1) || alarm !== (mode==2))
            $fatal(1,"Model mismatch count=%0d symbol=%0d state=%0d mode=%0d",count,symbol,state_number,mode);
        checks=checks+1;
        @(negedge clk); key=0; tick();
    endtask
    task fresh;
        // Alarm cannot be reset with the physical reset button.
        if(alarm) begin press(2); press(0); end
        @(negedge clk); reset=1; tick();
        @(negedge clk); reset=0;
        mode=0; count=0; correct=1; prev_e=0; alarm_w=0;
    endtask
    task sequence_check(input string seq, input integer expected_mode);
        fresh();
        for(integer i=0; i<seq.len(); i=i+1) begin
            case(seq[i])
                "E":press(0);
                "S":press(1);
                "W":press(2);
                default: $fatal(1,"Invalid test symbol");
            endcase
        end
        if(mode!=expected_mode) $fatal(1,"Handout sequence %s failed",seq);
        if(expected_mode==0 && state_number!=0) $fatal(1,"Expected reset for %s",seq);
    endtask
    task board_press(input integer symbol);
        @(negedge clk); #1;
        case(symbol) 0:e=1; 1:s=1; 2:w=1; 3:n=1; endcase
        repeat(12) tick();
        @(negedge clk); #1; e=0;s=0;w=0;n=0;
        repeat(12) tick();
    endtask
    integer value;
    bit saw_a, saw_off;
    initial begin
        tick();
        sequence_check("SWEW",1);
        sequence_check("SWEWS",0);
        sequence_check("SEE",0);
        sequence_check("WWEE",0);
        sequence_check("ESEE",0);
        sequence_check("WEE",0);
        sequence_check("EEWE",2);
        sequence_check("EEWEWE",0);
        sequence_check("SWSE",2);
        sequence_check("ESWWWE",0);
        sequence_check("WWES",2);
        sequence_check("WSSWE",0);
        sequence_check("ESWE",2);
        sequence_check("WSSSWE",0);
        // All 6,561 eight-key sequences; inspect outputs after EVERY key.
        for(integer pattern=0;pattern<6561;pattern=pattern+1) begin
            fresh(); value=pattern;
            repeat(8) begin press(value%3); value=value/3; end
        end
        sequence_check("SSSS",2);
        @(negedge clk); reset=1; tick();
        if(!alarm) $fatal(1,"Reset bypassed alarm");
        @(negedge clk); reset=0;
        press(0);press(0);
        if(!alarm) $fatal(1,"E-E bypassed alarm");
        fresh();
        @(negedge clk); key=3'b111; tick();
        if(state_number!=0) $fatal(1,"Simultaneous key accepted");
        @(negedge clk); key=0;
        // Real top-level paths: short bounce, held key, debounced release, LED bytes.
        @(negedge clk); #1; s=1; tick();
        @(negedge clk); #1; s=0; repeat(12) tick();
        if(led!=0) $fatal(1,"Bounce accepted");
        @(negedge clk); #1; s=1; repeat(100) tick();
        if(led!=1) $fatal(1,"Held S generated repeated presses");
        @(negedge clk); #1; s=0; repeat(12) tick();
        board_press(2); board_press(0); board_press(2);
        if(!board_unlock || board_alarm || led!=8'h55) $fatal(1,"Board unlock/ASCII U failed");
        board_press(0);
        if(board_unlock || led!=0) $fatal(1,"Any-key relock failed");
        repeat(4) board_press(1);
        if(!board_alarm) $fatal(1,"Board alarm failed");
        saw_a=0;saw_off=0;
        repeat(50) begin
            tick();
            if(led==8'h41) saw_a=1;
            else if(led==0) saw_off=1;
            else $fatal(1,"Invalid alarm LED byte");
        end
        if(!saw_a || !saw_off) $fatal(1,"Alarm does not blink");
        board_press(3);
        if(!board_alarm) $fatal(1,"North cleared alarm");
        board_press(2);board_press(0);
        if(board_alarm || led!=0) $fatal(1,"Board recovery failed");
        board_press(1);board_press(3);
        if(led!=0) $fatal(1,"North reset failed");
        $display("PASS: %0d core event checks, all handout sequences, exhaustive 8-key inputs, board debounce/hold/reset/LED/blink/recovery",checks);
        $finish;
    end
    initial begin #10000000; $fatal(1,"Timeout"); end
endmodule
