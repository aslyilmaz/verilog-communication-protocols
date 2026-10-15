`timescale 1ns / 1ps //3 decimals
//////////////////////////////////////////////////////////////////////////////////
module tb_brg(//no ports since tb
    );
    reg clk;
    reg rst_n;
    reg [1:0] baud_select;
    
    //outputs from DUT as wire
    wire rx_tick;
    wire tx_tick;
    
    //instantiate DUT
    baud_rate_generator dut_brg (
        .clk(clk),
        .rst_n(rst_n),
        .baud_select(baud_select),
        .tx_tick(tx_tick),
        .rx_tick(rx_tick)
        );
        
    //system clock generation
    always #5.208 clk = ~clk; //for 96 MHz
    
    integer first_tick = 1; //transition flag
    
    //timeline script
    initial begin
        clk = 0;
        rst_n = 0;
        first_tick = 1;
        baud_select = 2'b00; //start with desired baud rate of 9600
        
        #100; //to initialize the active low reset
        rst_n = 1; 
        
        #500000; //wait for 4-5 ticks
        
        baud_select = 2'b01; //19200 baud
        first_tick = 1;
        #250000; //4-5 ticks
        
        baud_select = 2'b10; //115200 baud
        first_tick = 1;
        #50000; //app. 5 ticks
        
        $finish;
    end
    
    real current_time;
    real last_time; //last tick time
    real time_delta; //time passed since the last tick
    real measured_baud;
    real expected_baud;
    real error;
    integer counter_rx = 0;
    
    always @(posedge rx_tick) begin
        counter_rx = counter_rx + 1;
    end
    
    always @(posedge tx_tick) begin
        current_time = $realtime;
    
        if (first_tick == 0) begin //no transition
            time_delta = current_time - last_time;
        
            if (baud_select == 2'b00) expected_baud = 9600.0;
            else if (baud_select == 2'b01) expected_baud = 19200.0;
            else if (baud_select == 2'b10) expected_baud = 115200.0;
        
            //check tick frequency
            measured_baud = 1000000000.0 / time_delta; //period to freq.
        
            //check tick alignment
            if (counter_rx == 16) begin  
                $display("Alignment verified: 16 RX ticks counted.");
            end else begin
                $display("Alignment error: %0d RX ticks counted instead of 16.", counter_rx);
            end
        
            //error calculation
            error = ((measured_baud - expected_baud) / expected_baud) * 100.0;
        
            $display("Measured Baud Rate: %f", measured_baud);
            $display("Expected Baud Rate: %f", expected_baud);
            $display("Error: %f %%", error);
        
       end else if (first_tick == 1) begin
            first_tick = 0;
            $display("Transition Flag: Math Skipped");
       end
    
        
        last_time = current_time;
        counter_rx = 0; //use blocking assignment for real and integer values
    end
endmodule
