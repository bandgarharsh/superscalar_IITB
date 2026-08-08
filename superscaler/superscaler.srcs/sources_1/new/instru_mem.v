`timescale 1ns / 1ps


module instru_mem(
    input clk,
    input[15:0] addr,
    output[15:0] instruct1,
    output[15:0] instruct2
    );
    
    reg[15:0] mem[0:255];
    initial begin
        $readmemh("instructions.mem", mem);
    end
    wire[14:0] word_addr = addr[15:1];
    assign instruct1 = (word_addr <= 15'd255) ? mem[word_addr] : 16'b0;
    assign instruct2 = (word_addr <= 15'd255) ? mem[word_addr + 1] : 16'b0;
endmodule
