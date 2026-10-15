module uart_rx (
	input wire clk,
	input wire rx_tick,
	input wire rst_n,
	input wire data_in,
	input wire parity_en,
	input wire parity_type,
	input wire stop_width,
	output reg [7:0] data_out,
	output reg parity_error,
	output reg rx_ready, //input to fifo
	output reg frame_error,
	output reg [2:0] current_state
);

reg [3:0] tick_counter;
reg [3:0] bit_counter;
reg [7:0] shift_reg;

localparam IDLE = 3'b000;
localparam START = 3'b001;
localparam DATA = 3'b010;
localparam PARITY = 3'b011;
localparam STOP = 3'b100;

//expected parity calculation
reg expected_parity;

always @(*) begin
	if (parity_en) begin //even parity
		if (!parity_type) begin
			expected_parity = ^shift_reg;
		end else begin //odd parity
			expected_parity = ~^shift_reg;
		end 
	end else begin
		expected_parity = 1'b0;
	end
end

//FSM
always @(posedge clk) begin
	if (!rst_n) begin
		tick_counter <= 4'b0000;
		bit_counter <= 4'b0000;
		current_state <= IDLE;
		shift_reg <= 8'b11111111; //0
		data_out <= 8'b11111111; //0
		rx_ready <= 1'b0;
		parity_error <= 1'b0;
		frame_error <= 1'b0;
	end else begin
		case (current_state)
		
			IDLE: begin
			rx_ready <= 1'b0;
			if (data_in == 1'b0) begin //checking start bit (low)
				tick_counter <= 4'b0000;
				parity_error <= 1'b0; //clear previous errors
				frame_error <= 1'b0;
				rx_ready <= 1'b0;
				current_state <= START;
			end
			end
			
			START: if (rx_tick) begin
				tick_counter <= tick_counter + 4'b0001;
				if (tick_counter == 4'b0111) begin //sample at the center
					if (data_in !== 1'b0) begin
					    current_state <= IDLE;
					end
				end
				if (tick_counter == 4'b1111) begin
						tick_counter <= 0;
						current_state <= DATA;
						bit_counter <= 0;
			    end
			end
			
			DATA: if (rx_tick) begin
				tick_counter <= tick_counter + 4'b0001;
				if (tick_counter == 4'b0111) begin //7th tick (sampling from the middle)
					shift_reg <= {data_in, shift_reg[7:1]};
		      	end
		      	if (tick_counter == 4'b1111) begin
		      	    bit_counter <= bit_counter + 4'b0001;
				    if (bit_counter == 4'b0111) begin //data ends after 8 bits
					   if (parity_en) begin
					       current_state <= PARITY;
					   end else begin
					       current_state <= STOP;
					   end
					   bit_counter <= 4'b0000;
					end
			    end
			end
			
			PARITY: if (rx_tick) begin
				tick_counter <= tick_counter + 4'b0001;
				if (tick_counter == 4'b0111) begin
					if (expected_parity != data_in) begin
						parity_error <= 1'b1; //parity error flag
					end
				end
				if (tick_counter == 4'b1111) begin
				    current_state <= STOP;
				    tick_counter <= 4'b0000;
				end
			end
			
			STOP: if (rx_tick) begin
				tick_counter <= tick_counter + 4'b0001;
				if (tick_counter == 4'b0111) begin //sampling from the middle
					if (data_in == 1'b0) begin
						frame_error <= 1'b1; //check the stop bit for frame error
					end
			    end
				if (tick_counter == 4'b1111) begin
				    bit_counter <= bit_counter + 4'b0001;	
					if (stop_width) begin //two stop bits
						if (bit_counter == 4'b0001) begin
							data_out <= shift_reg; //parallel output
							rx_ready <= 1'b1;
							current_state <= IDLE;
						end
					end else begin //one stop bit
						if (bit_counter == 4'b0000) begin
							data_out <= shift_reg;
							rx_ready <= 1'b1;
							current_state <= IDLE;
						end
					end
				end
			end
			default: current_state <= IDLE;
		endcase
	end
end
endmodule
