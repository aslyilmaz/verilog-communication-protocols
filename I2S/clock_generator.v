module clock_generator (
    input wire rst_n,
    input wire mclk, //master clock
    input wire [1:0] ratio_select, //runtime configurable master-clock ratio
    input wire [1:0] slot_select,
    output reg bclk, //bit clock
    output reg word_select,
    output reg illegal_conf_flag
);
//document achieved BCLK and WS frequencies for every legal configuration

    reg [5:0] slot_width;
    reg [4:0] divisor; //to accomodate 16 (at most)
    reg [3:0] mclk_counter;
    reg [6:0] bclk_counter;
    
    always @(*) begin
        case (slot_select)
            2'b00: slot_width = 6'b010000; //16
            2'b01: slot_width = 6'b011000; //24
            2'b10: slot_width = 6'b100000; //32
            default: slot_width = 6'b010000;
        endcase
    end

    //divisor = master clock ratio / (2 * slot width)
    always @(*) begin
        case (ratio_select)
            2'b00: //128
                divisor = 128 / (2 * slot_width);
            2'b01: //256
                divisor = 256 / (2 * slot_width);
            2'b10: //384
                divisor = 384 / (2 * slot_width);
            2'b11: //512
                divisor = 512 / (2 * slot_width);
        endcase
    end

    //WS toggles once for every full channel slot
    always @(posedge mclk) begin
        if (!rst_n) begin
            word_select <= 1'b0;
            bclk <= 1'b0;
            mclk_counter <= 4'b0000;
            bclk_counter <= 7'b0000000;
            illegal_conf_flag <= 1'b0;
        end else begin
            if (slot_width == 6'b011000 && (ratio_select == 2'b00 || ratio_select == 2'b01 || ratio_select == 2'b11)) begin
                illegal_conf_flag <= 1'b1;
            end else begin
                illegal_conf_flag <= 1'b0;
                if (mclk_counter >= (divisor >> 1) - 1) begin //50% duty cycle
                    bclk <= ~bclk;
                    mclk_counter <= 4'b0000;
                    //WS generation
                    if (bclk_counter == (slot_width << 1) - 1) begin
                        word_select <= ~word_select;
                        bclk_counter <= 7'b0000000;
                    end else begin
                        bclk_counter <= bclk_counter + 7'b0000001;
                    end
                end else begin
                    mclk_counter <= mclk_counter + 4'b0001;
                end
            end
        end
    end
endmodule
