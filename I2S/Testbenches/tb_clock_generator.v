`timescale 1ns / 1ps
module tb_clock_generator(
    );
    reg rst_n;
    reg mclk;
    reg [1:0] slot_select;
    reg [1:0] ratio_select;
    
    wire bclk;
    wire word_select;
    wire illegal_conf_flag;
    
    //for compatibility to both 48 kHz and 44.1 kHz families
    real mclk_half_period = 40.6901; // default 48kHz (in ns)
    always begin
        #mclk_half_period mclk = ~mclk;
    end
    
    //instantiate DUT
    clock_generator dut_clock_gen (
        .rst_n(rst_n),
        .mclk(mclk),
        .slot_select(slot_select),
        .ratio_select(ratio_select),
        .bclk(bclk),
        .word_select(word_select),
        .illegal_conf_flag(illegal_conf_flag)
    );
    
    //for period calculation
    real expected_ws_period;
    real expected_bclk_period;
    integer current_ratio_val;
    integer current_slot_val;
    integer divisor;
    
    task configure;
        input [1:0] ratio_sel;
        input [1:0] slot_sel;
        begin
            ratio_select = ratio_sel;
            slot_select = slot_sel;
            case (ratio_sel)
                2'b00: current_ratio_val = 128;
                2'b01: current_ratio_val = 256;
                2'b10: current_ratio_val = 384;
                2'b11: current_ratio_val = 512;
            endcase
            case (slot_sel)
                2'b00: current_slot_val = 16;
                2'b01: current_slot_val = 24;
                2'b10: current_slot_val = 32;
                default: current_slot_val = 16;
            endcase
            //dynamic expected BCLK period calculation
            divisor = current_ratio_val / (2 * current_slot_val);
            expected_bclk_period = mclk_half_period * 2 * divisor;
            
            //dynamic expected WS period calculation
            expected_ws_period = expected_bclk_period * 2 * current_slot_val;
        end
    endtask
    
    integer i; //slot
    integer k; //ratio
    integer bclk_first_tick;
    integer ws_first_tick;
    
    initial begin
        rst_n = 0;
        mclk = 0;
        bclk_first_tick = 1; //transition flag
        ws_first_tick = 1;
        
        #100;
        rst_n = 1;
        
        $display("Testing 48 kHz Family");
        mclk_half_period = 40.6901; //12.288 MHz
        for (i = 0; i < 3; i = i + 1) begin
            for (k = 0; k < 4; k = k + 1) begin
                configure(k, i);
                
                @(posedge mclk);
                rst_n = 0;
                @(posedge mclk);
                @(posedge mclk);
                rst_n = 1;
                #100000;
                
                bclk_first_tick = 1;
                ws_first_tick = 1;
                
                if (i == 1 && (k == 0 || k == 1 || k == 3)) begin
                    if (!illegal_conf_flag) begin
                        $display("Error: Illegal flag not raised when needed: Ratio %b, Slot %b", k[1:0], i[1:0]);
                        $stop;
                    end
                end else begin
                    if (illegal_conf_flag) begin
                        $display("Error: Illegal flag raised when not needed: Ratio %b, Slot %b", k[1:0], i[1:0]);
                        $stop;
                    end
                end
            end
        end
        
        $display("Testing 44.1 kHz Family");
        mclk_half_period = 44.2885; //11.2896 MHz
        for (i = 0; i < 3; i = i + 1) begin
            for (k = 0; k < 4; k = k + 1) begin
                configure(k, i);
                
                @(posedge mclk);
                rst_n = 0;
                @(posedge mclk);
                @(posedge mclk);
                rst_n = 1;
                #100000;
                
                bclk_first_tick = 1;
                ws_first_tick = 1;
                
                if (i == 1 && (k == 0 || k == 1 || k == 3)) begin
                    if (!illegal_conf_flag) begin
                        $display("Error: Illegal flag not raised when needed: Ratio %b, Slot %b", k[1:0], i[1:0]);
                        $stop;
                    end
                end else begin
                    if (illegal_conf_flag) begin
                        $display("Error: Illegal flag raised when not needed: Ratio %b, Slot %b", k[1:0], i[1:0]);
                        $stop;
                    end
                end
            end
        end
        
        $display("SIMULATION COMPLETE: ALL TESTS PASSED!");
        $finish;
    end
    
    integer bclk_counter = 0;
    
    real current_time;
    real last_time;
    real measured_bclk_period; //half period
    
    real high_duration;
    real low_duration;
    
    //verify frequency 
    always @(posedge bclk) begin
        current_time = $realtime;
        if (bclk_first_tick == 1) begin
            bclk_first_tick = 0;
        end else begin
            measured_bclk_period = current_time - last_time;
            //check BCLK frequency
            if ((measured_bclk_period < expected_bclk_period - 1.0) || 
                (measured_bclk_period > expected_bclk_period + 1.0)) begin
                $display("Error: BCLK frequency not verified. Period Expected %f ns, Measured %f ns", expected_bclk_period, measured_bclk_period);
                $stop;
            end
        end
        last_time = current_time;
    end
    
    real current_ws_time;
    real last_ws_time;
    real measured_ws_period;
    //WS frequency check
    always @(posedge word_select) begin
        current_ws_time = $realtime;
        if (ws_first_tick == 1) begin
            ws_first_tick = 0;
        end else if (last_ws_time > 0) begin
            measured_ws_period = current_ws_time - last_ws_time;
            if ((measured_ws_period < expected_ws_period - 1.0) || 
                (measured_ws_period > expected_ws_period + 1.0)) begin
                $display("Error: WS frequency not verified. Period Expected %f ns, Measured %f ns", expected_ws_period, measured_ws_period);
                $stop;
            end
        end
        last_ws_time = current_ws_time;
    end
    
    real bclk_edge_time;
    always @(bclk) begin 
        bclk_edge_time = $realtime;
    end
    //check WS/BCLK phase alignment
    always @(word_select) begin //since both posedge and negedge matters
        #0; //delta-cycle delay
        if ($realtime != bclk_edge_time && (ws_first_tick == 0) && (rst_n == 1)) begin //compare WS time with BCLK time
            $display("Error: WS and BCLK signals not aligned. Ratio %b, Slot %b", k[1:0], i[1:0]);
            $stop;
        end
    end
    
    //WS 50% duty cycle verification
    real ws_high_duration;
    real ws_low_duration;

    always @(negedge word_select) begin
        if (ws_first_tick == 0 && current_ws_time > 0 && (rst_n == 1)) begin
            ws_high_duration = $realtime - current_ws_time;
            if ((ws_high_duration < (expected_ws_period / 2.0) - 1.0) || 
                (ws_high_duration > (expected_ws_period / 2.0) + 1.0)) begin
                $display("Error: WS Duty Cycle not 50 percent. High Duration Measured %f ns, Expected %f at Ratio %b", ws_high_duration, (expected_ws_period / 2.0), k[1:0]);
                $stop;
            end
        end
        
    end
endmodule
