`timescale 1ns / 1ps
module fifo(
    input wire clk_r,
    input wire clk_w,
    input wire rst_w_n, //dual reset
    input wire rst_r_n,
    input wire [23:0] data_in,
    input wire write_en,
    input wire read_en,
    output reg [23:0] data_out,
    output wire rempty,
    output wire wfull
    );

    reg [23:0] memory_array [0:31];
    
    reg [5:0] pointer_r_bi; //extra bit for empty/full detection
    reg [5:0] pointer_w_bi;
    wire [5:0] pointer_r_gray = pointer_r_bi ^ (pointer_r_bi >> 1); //xor and shift
    wire [5:0] pointer_w_gray = pointer_w_bi ^ (pointer_w_bi >> 1);
    
    //synchronization
    reg [5:0] pointer_r_gray_sync;
    reg [5:0] pointer_w_gray_sync;
    reg [5:0] sync_ff_r;
    reg [5:0] sync_ff_w;
    //write to read
    always @(posedge clk_r or negedge rst_r_n) begin //clocking write pointer into read clock domain
        if (!rst_r_n) begin
            pointer_w_gray_sync <= 6'd0;
            sync_ff_w <= 6'd0;
        end else begin
            sync_ff_w <= pointer_w_gray;
            pointer_w_gray_sync <= sync_ff_w;
        end
    end
    //read to write
    always @(posedge clk_w or negedge rst_w_n) begin
        if (!rst_w_n) begin
            pointer_r_gray_sync <= 6'd0;
            sync_ff_r <= 6'd0;
        end else begin
            sync_ff_r <= pointer_r_gray;
            pointer_r_gray_sync <= sync_ff_r;
        end
    end
    
    assign rempty = (pointer_r_gray[5:0] == pointer_w_gray_sync[5:0]) ? 1'b1 : 1'b0;
    assign wfull = (pointer_w_gray == {~pointer_r_gray_sync[5:4], pointer_r_gray_sync[3:0]}) ? 1'b1 : 1'b0;
    
    //WRITE
    always @(posedge clk_w or negedge rst_w_n) begin //edge??
        if (!rst_w_n) begin
            pointer_w_bi <= 0;
        end else begin
            if (write_en && !wfull) begin
                memory_array[pointer_w_bi[4:0]] <= data_in;
                pointer_w_bi <= pointer_w_bi + 6'b000001;
            end
        end
    end
    
    //READ
    always @(posedge clk_r or negedge rst_r_n) begin
        if (!rst_r_n) begin
            pointer_r_bi <= 0;
            data_out <= 24'd0;
        end else begin
            if (read_en && !rempty) begin
                data_out <= memory_array[pointer_r_bi[4:0]];
                pointer_r_bi <= pointer_r_bi + 6'b000001;
            end
        end
    end
endmodule
