module seq_adder( 
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    output reg valid_out 
);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_out <= 8'd0;
        valid_out <= 1'b0;
    end
    else if(en) begin
        data_out <= data_out + data_in;
        valid_out <= 1'b1;
    end
    else begin
        valid_out <= 1'b0;
    end
end

endmodule