module sdm_1o (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               valid,
    input  wire signed [23:0] din,
    output reg                dout
);

    // ======================================
    // 输入锁存
    // ======================================

    reg signed [23:0] din_latched;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            din_latched <= 24'sd0;
        else if(valid)
            din_latched <= din;
    end

    // 扩展到40bit
    wire signed [39:0] din_ext =
        {{16{din_latched[23]}}, din_latched};

    // ======================================
    // 分频
    // ======================================

    reg [2:0] div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            div_cnt <= 3'd0;
        else
            div_cnt <= div_cnt + 1'b1;
    end

    wire sdm_en = (div_cnt == 3'd0);

    // ======================================
    // SDM核心
    // ======================================

    reg signed [39:0] integr;

    // 24bit FS * 1.2
    localparam signed [39:0] FB_POS =  40'sd10066330;
    localparam signed [39:0] FB_NEG = -40'sd10066330;

    wire signed [39:0] feedback =
        dout ? FB_POS : FB_NEG;

    // 误差
    wire signed [39:0] err =
        din_ext - feedback;

    // k = 0.5
    wire signed [39:0] err_scaled =
        err >>> 1;

    // 积分
    wire signed [39:0] integr_next =
        integr + err_scaled;

    // ======================================
    // 更新
    // ======================================

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            integr <= 40'sd0;
            dout   <= 1'b0;
        end
        else if(sdm_en) begin

            integr <= integr_next;

            dout <= (integr_next >= 0);

        end
    end

endmodule