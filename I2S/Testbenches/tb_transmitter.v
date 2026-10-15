`timescale 1ns / 1ps
module tb_transmitter(
    );
    
    reg rst_n;
    wire bclk;
    wire word_select;
    reg [1:0] slot_select;
    reg load_en;
    reg [23:0] data_in;
    wire underrun;
    wire tx_ready;
    wire data_out;
    
    reg mclk;
    reg [1:0] ratio_select;
    wire illegal_conf_flag;
    
    //instantiate DUT
    transmitter dut_transmitter(
        .mclk(mclk),
        .rst_n(rst_n),
        .bclk(bclk),
        .word_select(word_select),
        .slot_select(slot_select),
        .load_en(load_en),
        .data_in(data_in),
        .underrun(underrun),
        .tx_ready(tx_ready),
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

    integer n; //for slot width selection
    integer slot_bits;
    integer bit_index;
    integer i; //for test data selection
    reg [23:0] test_data [0:3]; //4 test data
    integer one_counter;
    integer zero_counter;
    integer data_bit_index;
    reg temp_ws;
    
    initial begin
        test_data[0] = 24'h000000;
        test_data[1] = 24'h55FF10;
        test_data[2] = 24'hAABBCC;
        test_data[3] = 24'hFFFFFF;
    
        rst_n = 0;
        mclk = 0;
        load_en = 0;
        one_counter = 0;
        zero_counter = 0;
        ratio_select = 0;
        #100000;
        rst_n = 1;
    
        for (n = 0; n < 3; n = n + 1) begin
            slot_select = n;
            
            case (n)
                0: ratio_select = 2'b00; // 128 -> divisor 4, fine for 16-bit slot
                1: ratio_select = 2'b10; // 384 -> divisor 8, the only legal ratio for 24-bit slot
                2: ratio_select = 2'b00; // 128 -> divisor 2, fine for 32-bit slot
            endcase
            
            for (i = 0; i < 4; i = i + 1) begin
                if (n == 0) slot_bits = 16;
                else if (n == 1) slot_bits = 24;
                else slot_bits = 32;
                
                data_in = test_data[i];
                load_en = 1;
                
                temp_ws = word_select;
                while (word_select == temp_ws) begin
                    @(negedge bclk);
                end
                @(negedge bclk);
                
                for (bit_index = slot_bits - 1; bit_index >= 0; bit_index = bit_index - 1) begin
                    //bit ordering and frame alignment control
                    @(posedge bclk); //receiver sampling at rising edge
                    data_bit_index = 23 - ((slot_bits - 1) - bit_index);
                    if (data_bit_index >= 0) begin
                        if (data_out != test_data[i][data_bit_index]) begin
                            $display("Frame Alignment Error at Data %h, Slot %d",test_data[i], slot_bits);
                            $stop;
                        end
                    end else begin
                        if (data_out != 0) begin
                            $display("Frame Alignment Error at Data %h, Slot %d",test_data[i], slot_bits);
                            $stop;
                        end
                    end
                    
                    //width handling control
                    if (i == 3 && n == 0) begin //data width is 24 and slot width is 16
                        if (data_out == 1) one_counter = one_counter + 1;
                    end
                    if (i == 3 && n == 2) begin //data width is 24 and slot width is 32
                        if (data_out == 0) zero_counter = zero_counter + 1;
                    end
                end
                
                //width handling error flags
                if (i == 3 && n == 0) begin //data width is 24 and slot width is 16
                    if (one_counter != 16) begin
                        $display("Error: Could not handle truncation. Ones Expected: 16, Got: %d", one_counter);
                        $stop;
                    end
                end
                if (i == 3 && n == 2) begin //data width is 24 and slot width is 32
                    if (zero_counter != 8) begin
                        $display("Error: Could not handle padding. Zeros Expected: 8, Got %d", zero_counter);
                        $stop;
                    end
                end
                
                load_en = 0;
                temp_ws = word_select;
                while (word_select == temp_ws) begin
                    @(negedge bclk);
                end
                @(negedge bclk);
                repeat(5) @(posedge mclk);
                
                if (!underrun) begin
                    $display("Error: Underrun flag not raised when needed.");
                    $stop;
                end
            end    
        end
        $display("SIMULATION COMPLETE: ALL TESTS PASSED!");
        $finish;
    end
endmodule
