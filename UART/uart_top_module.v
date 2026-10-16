`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
module uart_top_module #(
    parameter PARITY_EN = 1'b0,
    parameter PARITY_TYPE = 1'b0,
    parameter STOP_WIDTH = 1'b0
)(
    input wire clk,
    input wire rst_n,
    
    input wire user_write_en,  //triggers writing to TX FIFO
    input wire user_read_en,   //triggers reading from RX FIFO
    
    input wire rx_pin,
    input wire [7:0] SW,
    
    output wire tx_pin,
    output wire [7:0] LEDR
    );
    
    wire [2:0] current_state;
    wire parity_error, frame_error; // rx error flags
    wire tx_fifo_empty, tx_fifo_full;
    wire rx_fifo_empty, rx_fifo_full;
    wire tx_busy; // tx busy flag
    
    reg [7:0] user_data_in;
    
    // input the least significant 4 bits when the 4th switch is low
    // set 4th switch high and input the most significant 4 bits
    always @(posedge clk) begin
        if (SW[4] == 1'b0) begin
            user_data_in[3:0] <= SW[3:0];
        end else if (SW[4] == 1'b1) begin
            user_data_in[7:4] <= SW[3:0];
        end
    end
   
    wire [7:0] user_data_out;
    assign LEDR[7:0] = user_data_out;
    
    wire [1:0] baud_select = SW[7:6];
    
    wire tx_tick, rx_tick;
    wire [7:0] data_fifo_to_tx;
    wire [7:0] data_rx_to_fifo;
    wire rx_ready, tx_ready;
    
    //instantiate BRG
    baud_rate_generator BRG(
        .clk(clk),
        .rst_n(rst_n),
        .baud_select(baud_select),
        .tx_tick(tx_tick),
        .rx_tick(rx_tick)
    );
    
    //instantiate TX
    uart_tx TX(
        .clk(clk),
        .rst_n(rst_n),
        .tx_tick(tx_tick),
        .load_en(~tx_fifo_empty & tx_ready),
        .parity_en(PARITY_EN),
        .parity_type(PARITY_TYPE),
        .stop_width(STOP_WIDTH),
        .data_in(data_fifo_to_tx),
        .data_out(tx_pin),
        .tx_busy(tx_busy),
        .tx_ready(tx_ready)
    );
    
    //instantiate RX
    uart_rx RX(
        .clk(clk),
        .rst_n(rst_n),
        .rx_tick(rx_tick),
        .parity_en(PARITY_EN),
        .parity_type(PARITY_TYPE),
        .stop_width(STOP_WIDTH),
        .data_in(rx_pin),
        .data_out(data_rx_to_fifo),
        .parity_error(parity_error),
        .rx_ready(rx_ready),
        .frame_error(frame_error),
        .current_state(current_state)
    );
    
    //instantiate transmit FIFO
    uart_fifo TX_FIFO(
        .clk(clk),
        .rst_n(rst_n),
        .data_in(user_data_in),
        .write_en(user_write_en & ~tx_fifo_full),
        .read_en(tx_ready & ~tx_fifo_empty), 
        .data_out(data_fifo_to_tx),
        .empty(tx_fifo_empty),
        .full(tx_fifo_full)  
    );
    
    //instantiate receive FIFO
    uart_fifo RX_FIFO(
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_rx_to_fifo),
        .write_en(rx_ready & ~rx_fifo_full), 
        .read_en(user_read_en & ~rx_fifo_empty),
        .data_out(user_data_out),
        .empty(rx_fifo_empty),
        .full(rx_fifo_full)
    );
    
endmodule
