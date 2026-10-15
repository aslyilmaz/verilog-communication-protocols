`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
module tb_fifo(
);

    reg clk;
    reg rst_n;
    reg [7:0] data_in;
    reg write_en;
    reg read_en;
        
    wire [7:0] data_out;
    wire empty;
    wire full;
    
    //instantiate DUT
    uart_fifo dut_fifo(
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .write_en(write_en),
        .read_en(read_en),
        .data_out(data_out),
        .empty(empty),
        .full(full)  
    );
    
    //system clock generation
    always #5.208 clk = ~clk; //for 96 MHz
    
    integer i;
    
    initial begin
        clk = 0;
        rst_n = 0;
        read_en = 0;
        write_en = 0;
        data_in = 8'b00000000;
        
        #100;
        rst_n = 1;
        
        //writing check
        write_en = 1;
        for (i = 0; i < 16; i = i + 1) begin
            data_in = i;
            @(posedge clk);
            #1;
            if (dut_fifo.pointer_w[3:0] !== (i + 1) % 16) begin
                $display("Error: Write pointer does not match. Expected %d, Got %d", (i + 1) % 16, dut_fifo.pointer_w[3:0]);
                $stop;
            end
        end
        write_en = 0;
        #1;
        if (full !== 1) begin
            $display("Full Flag Error!");
            $stop;
        end
        
        //reading check
        read_en = 1;
        for (i = 0; i < 16; i = i + 1) begin
            @(posedge clk);
            #1;
            if (dut_fifo.pointer_r[3:0] !== (i + 1) % 16) begin
                $display("Error: Read pointer does not match. Expected %d, Got %d", (i + 1) % 16, dut_fifo.pointer_r[3:0]);
                $stop;
            end
        end
        read_en = 0;
        @(posedge clk);
        #1;
        if (dut_fifo.pointer_r[3:0] !== 0) begin
            $display("Error: Read pointer does not roll over. Expected 0, Got %d", dut_fifo.pointer_r[3:0]);
            $stop;
        end
        if (empty !== 1) begin
            $display("Empty Flag Error!");
            $stop;
        end
              
        $display("SIMULATION COMPLETE: ALL TESTS PASSED!");
        $finish; 
    end
endmodule
