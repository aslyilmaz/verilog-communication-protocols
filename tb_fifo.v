`timescale 1ns / 1ps
module tb_fifo(
);

    reg clk;
    reg mclk;
    reg rst_sys_n;
    reg rst_mclk_n;

    reg [23:0] tx_data_in;
    reg tx_write_en;
    reg tx_read_en;
    wire [23:0] tx_data_out;
    wire tx_rempty;
    wire tx_wfull;

    reg [23:0] rx_data_in;
    reg rx_write_en;
    reg rx_read_en;
    wire [23:0] rx_data_out;
    wire rx_rempty;
    wire rx_wfull;
    
    //instantiate DUT TX FIFO
    fifo dut_tx_fifo(
    .clk_r(mclk),
    .clk_w(clk),
    .rst_w_n(rst_sys_n),
    .rst_r_n(rst_mclk_n),
    .data_in(tx_data_in),
    .write_en(tx_write_en),
    .read_en(tx_read_en),
    .data_out(tx_data_out),
    .rempty(tx_rempty),
    .wfull(tx_wfull)
    );
    
    //instantiate DUT RX FIFO
    fifo dut_rx_fifo(
    .clk_r(clk),
    .clk_w(mclk),
    .rst_w_n(rst_mclk_n),
    .rst_r_n(rst_sys_n),
    .data_in(rx_data_in),
    .write_en(rx_write_en),
    .read_en(rx_read_en),
    .data_out(rx_data_out),
    .rempty(rx_rempty),
    .wfull(rx_wfull)
    );
    
    //master clock generation
    always #40.690 mclk = ~mclk;
    
    //system clock generation
    always #5.208 clk = ~clk; //for 96 MHz
    
    //deliberately mismatched read and write clock rates
    
    integer i;
    
    initial begin
        clk = 0;
        mclk = 0;
        rst_sys_n = 0;
        rst_mclk_n = 0;
        tx_write_en = 0;
        tx_read_en = 0;
        tx_data_in = 0;
        rx_write_en = 0;
        rx_read_en = 0;
        rx_data_in = 0;
        
        #200;
        rst_sys_n = 1;
        rst_mclk_n = 1;
        #100;
        
        //test TX FIFO
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            tx_write_en = 1;
            tx_data_in = 24'hA00000 + i;
        end
        @(posedge clk);
        tx_write_en = 0;
        
        #50;
        if (!tx_wfull) begin
            $display("Error: TX Full flag not raised when needed.");
            $stop;
        end
        
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge mclk);
            tx_read_en = 1;
            #1;
            if (tx_data_out !== 24'hA00000 + i) begin
                $display("Error: TX data does not match. Expected %h, Got %h", 24'hA00000 + i, tx_data_out);
                $stop;
            end
        end
        @(posedge mclk);
        tx_read_en = 0;
        
        //test RX FIFO
        for (i = 0; i < 4; i = i + 1) begin
            @(posedge mclk);
            rx_write_en = 1;
            rx_data_in = 24'hB00000 + i;
        end
        @(posedge mclk);
        rx_write_en = 0;
        
        @(posedge clk);
        while (rx_rempty) @(posedge clk);
        
        for (i = 0; i < 4; i = i + 1) begin
            @(posedge clk);
            rx_read_en = 1;
            #1;
            if (rx_data_out !== 24'hB00000 + i) begin
                $display("Error: RX data does not match. Expected %h, Got %h", 24'hB00000 + i, rx_data_out);
                $stop;
            end
        end
        @(posedge clk);
        rx_read_en = 0;
        
        #100;
        $display("SIMULATION COMPLETE: ALL TESTS PASSED!");
        $finish;
    end
endmodule
