
module ds_mash11 #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 24  // 增加位宽提供内部计算精度和动态范围
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid,
    input  wire signed [DATA_WIDTH-1:0] din, // 必须是有符号输入
    output wire                   dout
);

    // =========================================================================
    // 1. 零阶保持 (Zero-Order Hold)
    // =========================================================================
    // 当 valid 到来时锁存输入数据，在下一个 valid 到来前保持该值不变
    reg signed [DATA_WIDTH-1:0] din_hold;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_hold <= 0;
        end else if (valid) begin // 直接使用 AXI-Stream 的单拍脉冲即可
            din_hold <= din;
        end
    end

    // =========================================================================
    // 2. 常量与参数：反馈值 (Vref)
    // =========================================================================
    localparam signed [ACC_WIDTH-1:0] VREF = (1 << (DATA_WIDTH - 1)) + (1 << (DATA_WIDTH - 5));
    localparam signed [ACC_WIDTH-1:0] POS_LIMIT = (1 << (ACC_WIDTH - 1)) - 1;
    localparam signed [ACC_WIDTH-1:0] NEG_LIMIT = -(1 << (ACC_WIDTH - 1));

    reg  signed [ACC_WIDTH-1:0] integ1, integ2;
    reg  [1:0]quantized_out;

    // =========================================================================
    // 3. 负反馈逻辑 (Negative Feedback)
    // =========================================================================
    wire signed [ACC_WIDTH-1:0] feedback = quantized_out[1] ? VREF : -VREF;
    wire signed [ACC_WIDTH-1:0] in_ext   = $signed(din_hold); // ⭐ 使用锁存的数据

    // =========================================================================
    // 4. 带有饱和保护的积分逻辑 (CIFB 架构)
    // =========================================================================
    wire signed [ACC_WIDTH:0] next_integ1_raw = integ1 + (in_ext - feedback);
    wire signed [ACC_WIDTH:0] next_integ2_raw = integ2 + (integ1 - feedback);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integ1        <= 0;
            integ2        <= 0;
            quantized_out <= 0;
        end else begin   

            
            // 第一级积分器
            if (next_integ1_raw > POS_LIMIT)      
                integ1 <= POS_LIMIT;
            else if (next_integ1_raw < NEG_LIMIT) 
                integ1 <= NEG_LIMIT;
            else                                  
                integ1 <= next_integ1_raw[ACC_WIDTH-1:0];

            // 第二级积分器
            if (next_integ2_raw > POS_LIMIT)      
                integ2 <= POS_LIMIT;
            else if (next_integ2_raw < NEG_LIMIT) 
                integ2 <= NEG_LIMIT;
            else                                  
                integ2 <= next_integ2_raw[ACC_WIDTH-1:0];

            // 量化器 (优化：直接判断 next_integ2_raw 减少一拍环路延迟，提升系统稳定性)
            quantized_out[1] <= quantized_out[0];
            quantized_out[0] <= (next_integ2_raw >= 0);
        end
    end

    assign dout = quantized_out[0];

endmodule