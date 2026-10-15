`timescale 1ns / 1ps
module tb_receiver(
    );
    
    reg mclk;
    reg rst_n;
    wire bclk;
    wire word_select;
    reg [1:0] slot_select;
    reg data_in;
    reg fifo_full;
    wire [23:0] data_out;
    wire overrun;
    wire rx_ready;
    
    reg [1:0] ratio_select;
    wire illegal_conf_flag;

    //instantiate DUT
    receiver dut_receiver(
        .mclk(mclk),
        .rst_n(rst_n),
        .bclk(bclk),
        .word_select(word_select),
        .slot_select(slot_select),
        .ratio_select(ratio_select),
        .data_in(data_in),
        .fifo_full(fifo_full),
        .overrun(overrun),
        .rx_ready(rx_ready),
        .data_out(data_out)
    );

    //instantiate clock generator
    clock_generator clock_gen(
        .rst_n(rst_n),
        .mclk(mclk),
        .slot_select(slot_select),
        .ratio_select(ratio_select),
        .bclk(bclk),
        .word_select(word_select),
        .illegal_conf_flag(illegal_conf_flag)
    );
    
    //master clock generation
    always #40.690 mclk = ~mclk;
    
    task send_stereo_frame; //acts like transmitter
        input [23:0] i_data;
        input integer s_bits;
        integer m;
        integer data_index;
        reg current_ws;
        begin
            current_ws = word_select;
            while (word_select == current_ws) @(negedge bclk);
            @(negedge bclk);
            for (m = s_bits - 1; m >= 0; m = m - 1) begin
                data_index = m + 24 - s_bits;
                if (data_index >= 0) data_in = i_data[data_index];
                else data_in = 1'b0;
                @(negedge bclk);
            end
        end
    endtask
    
    integer n, i, k;
    reg [23:0] test_data [0:3];
    integer slot_bits;
    
    initial begin
        test_data[0] = 24'h000000;
        test_data[1] = 24'h55FF10;
        test_data[2] = 24'hAABBCC;
        test_data[3] = 24'hFFFFFF;

        mclk = 0;
        rst_n = 0;
        slot_select = 2'b01;
        ratio_select = 2'b10;
        fifo_full = 0;
        #100000;
        rst_n = 1;
        
        //arbitrary start point
        repeat(10) @(negedge bclk);
        data_in = 1'b1;
        repeat(5) @(negedge bclk);
        if (rx_ready) begin
            $display("Error: rx_ready flag raised on an incomplete frame");
            $stop;
        end

        for (n = 0; n < 3; n = n + 1) begin
            slot_select = n;
            case (n)
                0: ratio_select = 2'b00; // 128 -> divisor 4, fine for 16-bit slot
                1: ratio_select = 2'b10; // 384 -> divisor 8, the only legal ratio for 24-bit slot
                2: ratio_select = 2'b00; // 128 -> divisor 2, fine for 32-bit slot
            endcase
            
            if (n == 0) slot_bits = 16;
            else if (n == 1) slot_bits = 24;
            else slot_bits = 32;
            repeat(100) @(posedge mclk);
            
            for (i = 0; i < 4; i = i + 1) begin
                send_stereo_frame(test_data[i], slot_bits);
                @(posedge rx_ready);
                
                //width handling
                if (n == 0 && (data_out !== {test_data[i][23:8], 8'b0})) begin
                    $display("Error: Truncation failed at Expected Data %h, Got %h, Slot Width %d", test_data[i], data_out, slot_bits);
                    $stop;
                end else if (n > 0 && (data_out !== test_data[i])) begin
                    $display("Error: Data mismatch at Expected Data %h, Got %h, Slot Width %d", test_data[i], data_out, slot_bits);
                    $stop;
                end
                
                @(posedge mclk);
            end
        end
        
        //overrun
        fifo_full = 1;
        send_stereo_frame(test_data[1], slot_bits);
        repeat(slot_bits + 2)@(negedge bclk);
        if (!overrun) begin
            $display("Error: Overrun flag not raised when needed.");
            $stop;
        end
        fifo_full = 0;

        //BCLK stop/restart
        repeat(5) @(negedge bclk);
        force bclk = 1'b0;
        repeat(50) @(posedge mclk);
        release bclk;
        repeat(100) @(posedge mclk);
        send_stereo_frame(test_data[1], slot_bits);
        @(posedge rx_ready);
        if (data_out !== test_data[1]) begin
            $display("Error: Data mismatch at Data %h, Slot Width %d when BCLK restarted.", test_data[1], slot_bits);
            $stop;
        end
        
        $display("SIMULATION COMPLETE: ALL TESTS PASSED!");
        $finish;    
    end
endmodule
