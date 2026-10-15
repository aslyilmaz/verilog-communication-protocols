`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
module tb_tx(
    );
    reg clk;
    reg rst_n;
    reg load_en;
    reg parity_en;
    reg parity_type;
    reg stop_width;
    reg [7:0] data_in;
    reg [1:0] baud_select;
    
    wire data_out;
    wire tx_busy;
    wire tx_ready;
    wire tx_tick;
    wire rx_tick;
    
    
    //instantiate BRG
    baud_rate_generator BRG(
        .clk(clk),
        .rst_n(rst_n),
        .baud_select(baud_select),
        .tx_tick(tx_tick),
        .rx_tick(rx_tick)
    );
    
    //instantiate DUT
    uart_tx dut_tx(
        .clk(clk),
        .rst_n(rst_n),
        .tx_tick(tx_tick),
        .load_en(load_en),
        .parity_en(parity_en),
        .parity_type(parity_type),
        .stop_width(stop_width),
        .data_in(data_in),
        .data_out(data_out),
        .tx_busy(tx_busy),
        .tx_ready(tx_ready)
    );
    
    //system clock generation
    always #5.208 clk = ~clk; //for 96 MHz
    
    task baud_rate;
        input [1:0] baud_sel;
        begin
            baud_select = baud_sel;
        end
    endtask
    
    task tx_specs;
        input
        p_en,
        p_type,
        s_width;
        begin
            parity_en = p_en;
            parity_type = p_type;
            stop_width = s_width;
            @(posedge clk);
        end
    endtask
    
    integer tick_counter = 0;
    
    task send_data; 
        input [7:0] i_data;
        begin
            wait(!tx_busy); //wait for transmitter to be ready for upcoming data
            @(posedge clk);
            data_in = i_data;
            load_en = 1;
            tick_counter = 0;
            @(posedge clk);
            load_en = 0;
            
            //tx_busy timing check
            @(posedge clk);
            if (tx_busy !== 1'b1) begin //rising edge
                $display("Error: tx_busy not activated when load enabled.");
                $stop;
            end
            @(negedge tx_busy); //falling edge
            if (data_out !== 1'b1) begin
                $display("Error: Not returning to idle state when tx_busy deactivated.");
                $stop;
            end
        end
    endtask
    
    integer n;
    integer k;
    reg [2:0] test_specs [0:5]; //6 different cases of tx_specs
    integer i;
    reg [7:0] test_data [0:3]; //4 different test data
    
    initial begin
        test_data[0] = 8'h00;
        test_data[1] = 8'h55;
        test_data[2] = 8'hAA;
        test_data[3] = 8'hFF;
        
        //parity_en, parity_type, stop_width
        test_specs[0] = 3'b000; //no parity, 1 stop bit
        test_specs[1] = 3'b001; //no parity, 2 stop bits
        test_specs[2] = 3'b100; //even parity, 1 stop bit
        test_specs[3] = 3'b101; //even parity, 2 stop bits
        test_specs[4] = 3'b110; //odd parity, 1 stop bit
        test_specs[5] = 3'b111; //odd parity, 2 stop bits
    
        clk = 0;
        rst_n = 0;
        
        #100;
        rst_n = 1;
        
        for (n = 0; n < 3; n = n + 1) begin
            baud_rate(n);
            #100;
            
            for (k = 0; k < 6; k = k + 1) begin
                tx_specs(test_specs[k][2], test_specs[k][1], test_specs[k][0]);
                #100;
                
                for (i = 0; i < 4; i = i + 1) begin
                    send_data(test_data[i]);
                    wait(tx_ready);
                    #100;
                end
            end
        end        

        $display("SIMULATION COMPLETE: ALL TESTS PASSED!");
        $finish; 
    end
    
    integer expected_parity;
    integer frame_length;
    integer parity_index = 9;
    integer first_stop_index;
    
    
    always @(posedge tx_tick) begin
        if (tx_busy) begin
            if (parity_en) begin
                first_stop_index = 10;
            end else if (!parity_en) begin
                first_stop_index = 9;
            end
            if (tick_counter == 0) begin
                if (data_out != 0) begin //start bit
                    $display("Error: Start bit not detected.");
                    $display("Error at Data: %h, Baud Rate: %b", data_in, baud_select);
                    $stop;
                end
            end else if (tick_counter >= 1 && tick_counter <= 8) begin //data bits
                //check data_in[i] = tx_out at tick_counter = i + 1
                    if (data_out != data_in[tick_counter - 1]) begin
                        $display("Error: Data does not match. Expected %b, Obtained %b", data_in[tick_counter - 1], data_out);
                        $stop;
                    end
            end else if (parity_en == 1 && tick_counter == parity_index) begin //parity check
                if (parity_type == 1'b1) begin //odd parity
                    expected_parity = ~^data_in;                    
                end else begin //even parity
                    expected_parity = ^data_in;
                end
                if (expected_parity != data_out) begin //check indentation
                    $display("Error: Parity does not match.");
                    $display("Expected Parity: %b, Data Read: %b", expected_parity, data_out);
                    $stop;
                end
            end else if (tick_counter >= first_stop_index) begin
                if (data_out == 0) begin
                    $display("Error: Stop bit not detected.");
                    $display("Error at Data: %h, Stop Bit Selection: %b", data_in, stop_width);
                    $stop;
                end
            end
            tick_counter = tick_counter + 1;
        end else begin
            tick_counter = 0; //if tx not busy
        end
    end
endmodule
