`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
module tb_rx(
    );
    reg clk;
    reg rst_n;
    reg data_in;
    reg parity_en;
	reg parity_type;
	reg stop_width;
	reg [1:0] baud_select;
	
	wire [7:0] data_out;
	wire parity_error;
	wire rx_ready;
	wire frame_error;
	wire [2:0] current_state;
	wire rx_tick;
	wire tx_tick;
	
	//instantiate BRG
	baud_rate_generator BRG(
        .clk(clk),
        .rst_n(rst_n),
        .baud_select(baud_select),
        .tx_tick(tx_tick),
        .rx_tick(rx_tick)
    );
	
	//instantiate DUT
	uart_rx dut_rx(
        .clk(clk),
        .rst_n(rst_n),
        .rx_tick(rx_tick),
        .parity_en(parity_en),
        .parity_type(parity_type),
        .stop_width(stop_width),
        .data_in(data_in),
        .data_out(data_out),
        .parity_error(parity_error),
        .rx_ready(rx_ready),
        .frame_error(frame_error),
        .current_state(current_state)
    );
	
	//system clock generation
    always #5.208 clk = ~clk; //for 96 MHz
    
    reg rx_ready_caught = 0;
    always @(posedge clk) begin
        if (rx_ready == 1'b1) begin
            rx_ready_caught <= 1;
        end
    end
    
    integer tick_counter;
    integer expected_parity;
    integer n;
    integer k;
    reg [2:0] test_specs [0:5]; //6 different cases of rx_specs
    integer i;
    reg [7:0] test_data [0:3]; //4 different test data
    integer expected_ticks;
    reg receiving = 0;
    reg rx_ready_d = 0;
    integer m;
    integer parity_error_inj;
    integer frame_error_inj;
    
    task baud_rate;
        input [1:0] baud_sel;
        begin
            baud_select = baud_sel;
        end
    endtask
    
    task rx_specs;
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
    
    task send_data; //needs to act like the tx module
        input [7:0] i_data;
        input [1:0] error_injection; //0: no error, 1: parity error, 2: framing error
        integer i;
        begin
            parity_error_inj = 0;
            frame_error_inj = 0;
        
            @(posedge tx_tick);
            data_in = 0; //start bit
            @(posedge tx_tick);
            
            //data bits
            for (i=0; i<8; i = i + 1) begin
                data_in = i_data[i];
                @(posedge tx_tick);
            end
            
            //parity bit
            if (parity_en) begin
                if (error_injection == 2'b01) begin //test parity error
                    parity_error_inj = 1;
                    if (parity_type == 1'b1) begin
                        expected_parity = ^i_data;
                    end else if (parity_type == 1'b0) begin
                        expected_parity = ~(^i_data);
                    end
                end else begin
                    parity_error_inj = 0;
                    if (parity_type == 1'b1) begin //odd parity
                        expected_parity = ~(^i_data);                    
                    end else if (parity_type == 1'b0) begin //even parity
                        expected_parity = ^i_data;
                    end
                end
                data_in = expected_parity;
                @(posedge tx_tick);
            end
            
            if (error_injection == 2'b10) begin //test frame error
                frame_error_inj = 1;
                data_in = 0;
            end else begin
                frame_error_inj = 0;
                data_in = 1; //first stop bit
            end
            @(posedge tx_tick);
            if (stop_width) begin
                data_in = 1; //second stop bit
                @(posedge tx_tick);
            end
            data_in = 1;
        end
    endtask
   
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
        data_in = 1;
        
        #100;
        rst_n = 1;
        
        for (n = 0; n < 3; n = n + 1) begin
            baud_rate(n);
            #100;
                
            for (m = 0; m < 3; m = m + 1) begin
                for (k = 0; k < 6; k = k + 1) begin
                    rx_specs(test_specs[k][2], test_specs[k][1], test_specs[k][0]);
                    #100;
                    
                    for (i = 0; i < 4; i = i + 1) begin
                        send_data(test_data[i], m);
                        
                        begin: wait_for_rx
                            integer timeout;
                            timeout = 0;
                            while (rx_ready_caught == 0 && timeout < 5000) begin
                                @(posedge clk);
                                timeout = timeout + 1;
                            end
                            if (rx_ready_caught == 0) begin
                                $display("Error: rx_ready never fired!");
                                $stop;
                            end
                            rx_ready_caught = 0;
                        end
                    
                        //data framing check
                        if (data_out !== test_data[i]) begin
                            $display("Error: Data sent does not match the output. Expected: %b, Received: %b", test_data[i], data_out);
                            $stop;
                        end
                        //parity check
                        if (parity_error_inj == 1) begin
                            if (!parity_error) begin
                                $display("Error: No parity error flag when needed at test data %b", test_data[i]);
                                $stop;
                            end
                        end else begin
                            if (parity_error) begin
                                $display("Error: Unexpected parity error flag at test data %b", test_data[i]);
                                $stop;
                            end
                        end
                        //test frame error
                        if (frame_error_inj) begin
                            if (!frame_error) begin
                                $display("Error: No frame error flag when needed at test data %b", test_data[i]);
                                $stop;
                            end
                        end else begin
                            if (frame_error) begin
                                $display("Error: Unexpected frame error flag at test data %b", test_data[i]);
                                $stop;
                            end
                        end
                        
                        //oversampling check
                        expected_ticks = 16 * (10 + parity_en + stop_width);
                        if (tick_counter < (expected_ticks - 1) || tick_counter > (expected_ticks + 1)) begin //one tick tolerance
                            $display("Oversampling Error");
                            $stop;
                        end
                        receiving = 0;
                        @(posedge tx_tick); //??    
                    end    
                end
            end
        end
        
        $display("SIMULATION COMPLETE: ALL TESTS PASSED!");
        $finish; 
    end

    //oversampling alignment
    always @(posedge rx_tick) begin
        if (data_in == 0 && receiving == 0) begin //start bit
            receiving = 1;
            tick_counter = 0; 
        end 
        if (receiving == 1) begin
            tick_counter = tick_counter + 1;
        end
    end
    //synchronized behaviour
endmodule
