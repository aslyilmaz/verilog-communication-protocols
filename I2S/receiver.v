`timescale 1ns / 1ps
module receiver (
    input wire mclk,
    input wire rst_n,
    input wire bclk,
    input wire word_select,
    input wire [1:0] slot_select,
    input wire [1:0] ratio_select,
    input wire data_in,
    input wire fifo_full,
    output reg [23:0] data_out,
    output reg overrun,
    output reg rx_ready //ready to write parallel data to receive FIFO
    );
    
    //sample the incoming data line on the correct BCLK edge and assemble stereo samples into the receive FIFO
    //align to the frame using the WS transition rather than assuming a starting point
    //reveiver may be enabled at any moment (partway through a frame) and must not emit a misaligned sample
    //handle the same slot-width data-width conf. as the transmitter...
    //...taking the word from the leading bit positions of each slot and discarding the remainder
    //define and implement overrun behavior when the receive FIFO is full (status condition)
    //recover cleanly if BCLK stops and later restarts or if the frame rate changes -do not require a reset to resynchronize
    
    reg [5:0] slot_width;
    
    always @(*) begin
        case (slot_select)
            2'b00: slot_width = 6'b010000; //16
            2'b01: slot_width = 6'b011000; //24
            2'b10: slot_width = 6'b100000; //32
            default: slot_width = 6'b010000;
        endcase
    end
    
    reg ws_prev;
    reg bclk_prev;
    reg [1:0] ratio_select_prev;
    //edge detection
    always @(posedge mclk or negedge rst_n) begin
        if (!rst_n) begin
            bclk_prev <= 1'b0;
            ratio_select_prev <= 2'b00;
        end else begin
            bclk_prev <= bclk;
            ratio_select_prev <= ratio_select; //ratio??
        end
    end
    
    wire bclk_rising = bclk & ~bclk_prev;
    
    reg [31:0] shift_reg;
    reg [5:0] bit_counter;
    
    reg load_pending;
    reg [1:0] sync_count;
    //for BCLK restart recovery
    reg [7:0] bclk_timeout_counter;
    wire bclk_stopped = (bclk_timeout_counter > 8'd40);
    always @(posedge mclk or negedge rst_n) begin
        if (!rst_n) bclk_timeout_counter <= 8'd0;
        else begin
            if (bclk_rising) begin
                bclk_timeout_counter <= 8'd0;
            end else if (!bclk_stopped) begin
                bclk_timeout_counter <= bclk_timeout_counter + 8'd1;
            end
        end
    end
    
    always @(posedge mclk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 32'h0;
            bit_counter <= 6'b0;
            overrun <= 1'b0;
            rx_ready <= 1'b0;
            load_pending <= 1'b0;
            sync_count <= 2'b00;
            ws_prev <= 1'b0;
            data_out <= 24'h0;
        end else begin
            if (rx_ready) rx_ready <= 1'b0; //pulse
            if (bclk_stopped || (ratio_select != ratio_select_prev) ) begin //bit clock stopped
                sync_count <= 2'b00;
                load_pending <= 1'b0;
            end
            if (bclk_rising) begin
                ws_prev <= word_select;
                if (ws_prev != word_select) begin
                    load_pending <= 1'b1;
                    shift_reg[31 - bit_counter] <= data_in;
                end else if (load_pending == 1'b1) begin
                    load_pending <= 1'b0;
                    bit_counter <= 6'b0;
                    if (sync_count >= 2'b10) begin
                        if (!fifo_full) begin
                            overrun <= 1'b0;
                            if (slot_select == 2'b00) data_out <= {shift_reg[31:16], 8'h00};
                            else data_out <= shift_reg[31:8];
                            rx_ready <= 1'b1;
                        end else begin
                            overrun <= 1'b1;
                        end
                    end else begin
                        sync_count <= sync_count + 2'b01;
                    end
                    shift_reg <= {data_in, 31'b0}; //write MSB
                    bit_counter <= 6'b000001;
                end else begin
                    shift_reg[31 - bit_counter] <= data_in;
                    bit_counter <= bit_counter + 6'b000001;
                end
            end
        end
    end
endmodule
