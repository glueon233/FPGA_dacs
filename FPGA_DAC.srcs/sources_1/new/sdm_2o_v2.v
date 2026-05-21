module sdm_2nd #
(
    parameter INPUT_WIDTH = 20,
    parameter INTEG_WIDTH = 32
)
(
    input wire clk,
    input wire rst_n,
    input wire signed [INPUT_WIDTH-1:0] pcm_in,
    output reg pdm_out
);



localparam signed [INPUT_WIDTH-1:0] DAC_LEVEL =
    (1 <<< (INPUT_WIDTH-1)) - 1;

wire signed [INPUT_WIDTH-1:0] dac_out =
    pdm_out ? DAC_LEVEL : -DAC_LEVEL;

// 符号扩展
wire signed [INTEG_WIDTH-1:0] pcm_ext =
    {{(INTEG_WIDTH-INPUT_WIDTH){pcm_in[INPUT_WIDTH-1]}}, pcm_in};

wire signed [INTEG_WIDTH-1:0] dac_ext =
    {{(INTEG_WIDTH-INPUT_WIDTH){dac_out[INPUT_WIDTH-1]}}, dac_out};

// 积分器
reg signed [INTEG_WIDTH-1:0] integ1;

wire signed [INTEG_WIDTH-1:0] delta1;

wire signed [INTEG_WIDTH-1:0] sum1;


assign delta1 = pcm_ext - dac_ext;

assign sum1 = integ1 + delta1;



always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        integ1 <= 0;
;
        pdm_out <= 0;
    end
    else begin
        integ1 <= sum1;
        pdm_out <= (sum1 >= 0);
    end
end

endmodule