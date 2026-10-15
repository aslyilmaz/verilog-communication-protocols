module baud_rate_generator #(
	parameter clk_rate = 96000000 //96 MHz system clock
)(
	input wire clk,
	input wire rst_n, //active low reset
	input wire [1:0] baud_select,
	output reg tx_tick,
	output reg rx_tick
);

reg [10:0] prescaler_rx;
reg [14:0] prescaler_tx;

reg [14:0] counter_tx;
reg [10:0] counter_rx;

//runtime configurable desired baud rate
localparam DIV_9600 = 625;
localparam DIV_19200 = 312; //312.5
localparam DIV_115200 = 52; //52.08

always @(*) begin
	case (baud_select)
		2'b00: begin prescaler_rx = DIV_9600;
			prescaler_tx = DIV_9600 * 16;
		end
			
		2'b01: begin prescaler_rx = DIV_19200;
			prescaler_tx = DIV_19200 * 16;
		end
		
		2'b10: begin prescaler_rx = DIV_115200;
			prescaler_tx = DIV_115200 * 16;
		end
		default: begin prescaler_rx = DIV_9600;
			prescaler_tx = DIV_9600 * 16;
		end
	endcase
end

always @(posedge clk) begin
	//e.g. counter counts from 0 to 624
	//when it rolls over
	//receiver takes 1/16th step 
	//after 16 of these steps
	//one bit of data has passed at 9600 baud
	
	if (!rst_n) begin
		tx_tick <= 1'b0;
		rx_tick <= 1'b0;
		counter_tx <= 0;
		counter_rx <= 0;
	end else begin
		//TX
		if (counter_tx >= prescaler_tx[14 : 0] - 1'b1) begin
			counter_tx <= 0;
			tx_tick <= 1'b1; //one cycle tick
		end
		else begin
			counter_tx <= counter_tx + 1'b1;
			tx_tick <= 1'b0;
		end
		//RX
		if (counter_rx >= prescaler_rx[10 : 0] - 1'b1) begin
			counter_rx <= 0;
			rx_tick <= 1'b1;
		end
		else begin
			counter_rx <= counter_rx + 1'b1;
			rx_tick <= 1'b0;
		end
	end
end
endmodule
