module uart_tx (
	input wire tx_tick,
	input wire clk,
	input wire rst_n,
	input wire parity_en, //parity w/ enable
	input wire parity_type, //odd or even parity
	input wire stop_width, //configurable stop bits (1 or 2)
	input [7:0] data_in,
	input load_en, //?
	output wire data_out,
	output reg tx_busy,
	output reg tx_ready //ready to pull data from fifo
);

//detemining the output size
reg [3:0] output_width;

always @(*) begin
	case ({parity_en, stop_width})
		2'b00: output_width = 4'd10;
		2'b01: output_width = 4'd11;
		2'b10: output_width = 4'd11;
		2'b11: output_width = 4'd12;
	endcase
end

//parity generator
reg parity_bit;

always @(*) begin
	if (parity_en) begin //even parity
		if (!parity_type) begin
			parity_bit = ^data_in; //xor
		end else begin //odd parity
			parity_bit = ~^data_in;
		end 
	end else begin
		parity_bit = 1'b0;
	end
end

//SHIFT REGISTER
reg [11:0] shift_reg; //no dynamic reg
reg [3:0] bit_counter;
assign data_out = shift_reg[0];

always @(posedge clk) begin
	if (!rst_n) begin
		shift_reg <= 12'b111111111111; //idle state high since start bit low
		tx_busy <= 1'b0;
		bit_counter <= 0;
		tx_ready <= 1'b1;
	end
	else if (load_en) begin
		//idle, stop bit(s), parity (if enabled), data, start bit
		tx_busy <= 1'b1;
		tx_ready <= 1'b0;
		//shift register definition according to spec. combinations
		case ({parity_en, stop_width})
			2'b00: shift_reg <= {1'b1, 1'b1, 1'b1, data_in, 1'b0};
			2'b01: shift_reg <= {1'b1, 1'b1, 1'b1, data_in, 1'b0};
			2'b10: shift_reg <= {1'b1, 1'b1, parity_bit, data_in, 1'b0};
			2'b11: shift_reg <= {1'b1, 1'b1, parity_bit, data_in, 1'b0};
		endcase
	end
	else if (tx_tick & tx_busy) begin
		bit_counter <= bit_counter + 1'b1;
		shift_reg <= {1'b1, shift_reg[11:1]}; //shifting right
		if (bit_counter == output_width) begin
			tx_busy <= 1'b0;
			tx_ready <= 1'b1;
			bit_counter <= 0;
		end
	end
end
endmodule
