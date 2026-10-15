module transmitter (
    input wire mclk, //master clock
    input wire rst_n,
    input wire bclk,
    input wire word_select,
    input wire [1:0] slot_select,
    input wire load_en, //coming from transmit FIFO
    input wire [23:0] data_in, //data incoming from the transmit FIFO
    output reg underrun, //underrun behavior flag
    output reg tx_ready, //ready to pull data from FIFO
    output wire data_out //serial outgoing data
);

    reg [5:0] slot_width;
    
    always @(*) begin
        case (slot_select)
            2'b00: slot_width = 6'b010000; //16
            2'b01: slot_width = 6'b011000; //24
            2'b10: slot_width = 6'b100000; //32
            default: slot_width = 6'b010000;
        endcase
    end
    
    reg bclk_prev;
    always @(posedge mclk or negedge rst_n) begin
        if (!rst_n) begin
            bclk_prev <= 1'b0;
        end else begin
            bclk_prev <= bclk;
        end
    end
    
    //BCLK trailing edge detection
    wire bclk_falling = ~bclk & bclk_prev;
    
    reg [31:0] shift_reg; //at most 32 slot width
    reg [5:0] bit_counter;
    reg load_pending; //for the one-bit delay
    reg ws_prev; //tracking WS on bit clock
    
    assign data_out = shift_reg[31];
    
    //data changes on the falling BCLK edge
    always @(posedge mclk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 32'h0;
            underrun <= 1'b0;
            tx_ready <= 1'b1;
            bit_counter <= 6'b0;
            load_pending <= 1'b0;
            ws_prev <= 1'b0;
        end else begin
            if (bclk_falling) begin
                ws_prev <= word_select;
                if (word_select != ws_prev) begin //WS transition
                    bit_counter <= 6'b0;
                    tx_ready <= 1'b1;
                    shift_reg <= {shift_reg[30:0], 1'b0}; //shifting the LSB
                    load_pending <= 1'b1;
                end else if (load_pending) begin
                        tx_ready <= 1'b0;
                        load_pending <= 1'b0;
                        if (load_en) begin //transmit FIFO ready
                            shift_reg <= {data_in, 8'h00};
                            underrun <= 1'b0;
                        end else begin //FIFO empty
                            underrun <= 1'b1;
                            shift_reg <= 32'h0;
                        end
                    bit_counter <= 6'b1;
                end else begin
                    shift_reg <= {shift_reg[30:0], 1'b0}; //shifting left
                    tx_ready <= 1'b0;
                    if (bit_counter < slot_width) begin
                        bit_counter <= bit_counter + 6'b000001;
                    end else begin
                        bit_counter <= 6'b0;
                        shift_reg <= 32'b0;
                    end
                end
            end
        end
    end
endmodule