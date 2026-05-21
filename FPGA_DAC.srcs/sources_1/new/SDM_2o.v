module sdm_2o (
    input  wire        clk,      // 系统高速时钟 
    input  wire        rst_n,
    input  wire        valid,    // 上游数据有效脉冲 (触发锁存)
    input  wire [23:0] din,      // 输入 24-bit 有符号 PCM (FIR 全精度输出)
    output reg         dout      // 输出 1-bit PDM
);

    // ==========================================
    // 0. 输入数据锁存逻辑
    // ==========================================
    reg signed [23:0] din_latched;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_latched <= 24'sd0;
        end else if (valid) begin
            din_latched <= din; 
        end
    end

    // 符号扩展到 32-bit
    wire signed [31:0] din_ext = {{8{din_latched[23]}}, din_latched};


    // ==========================================
    // 1. 内部 16 分频器逻辑 (产生 sdm_en)
    // ==========================================
    reg [3:0] clk_div_cnt;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_cnt <= 4'd0;
        end else begin
            clk_div_cnt <= clk_div_cnt + 1'b1;
        end
    end

    wire sdm_en = (clk_div_cnt == 4'd7);


    // ==========================================
    // 2. 内部 32-bit 寄存器与反馈常数
    // ==========================================
    // 对应图中的两个 z^-1 / (1 - z^-1) 积分器状态
    reg signed [31:0] integr1;
    reg signed [31:0] integr2;

    // 反馈值 Y: 匹配 24-bit 输入的满量程 (+/- 8388607)
    localparam signed [31:0] FB_POS =  32'sd8388607;
    localparam signed [31:0] FB_NEG = -32'sd8388608;

    // 32-bit 饱和截断边界
    localparam signed [32:0] MAX_32 =  33'sd2147483647;
    localparam signed [32:0] MIN_32 = -33'sd2147483648;


    // ==========================================
    // 3. 核心组合逻辑：严格映射 Simulink 数据流
    // ==========================================
    
    // 【关键】组合逻辑提取量化器输出 (Sign)
    // 根据图纸，反馈路径是没有延迟的，必须基于当前的 integr2 立刻判断
    wire dout_comb = (integr2 >= 32'sd0);
    
    // 生成反馈信号 Y (增益为 1 的三角符号)
    wire signed [31:0] feedback = dout_comb ? FB_POS : FB_NEG;

    // --- 第一级 ---
    // 1. 输入乘以 1/2 (通过算术右移 1 位实现，不占乘法器)
    wire signed [31:0] din_half = din_ext >>> 1;
    // 2. 减去反馈信号 Y
    wire signed [31:0] err1 = din_half - feedback;
    // 3. 积分器累加 (33-bit 防溢出)
    wire signed [32:0] sum1 = integr1 + err1;
    
    // 饱和截断
    wire signed [31:0] integr1_next = 
        (sum1 > MAX_32) ? MAX_32[31:0] :
        (sum1 < MIN_32) ? MIN_32[31:0] : 
        sum1[31:0];

    // --- 第二级 ---
    // 1. 第一级输出乘以 1/2
    wire signed [31:0] int1_half = integr1 >>> 1;
    // 2. 减去反馈信号 Y
    wire signed [31:0] err2 = int1_half - feedback;
    // 3. 积分器累加 
    wire signed [32:0] sum2 = integr2 + err2;
    
    // 饱和截断
    wire signed [31:0] integr2_next = 
        (sum2 > MAX_32) ? MAX_32[31:0] :
        (sum2 < MIN_32) ? MIN_32[31:0] : 
        sum2[31:0];


    // ==========================================
    // 4. 时序逻辑：状态更新 (对应积分器内部的 z^-1)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integr1 <= 32'sd0;
            integr2 <= 32'sd0;
            dout    <= 1'b0;
        end 
        else if (sdm_en) begin 
            // 积分器寄存器更新
            integr1 <= integr1_next;
            integr2 <= integr2_next;
            // 将组合逻辑计算出的量化结果打一拍输出，保证外部时序干净
            dout    <= dout_comb;
        end
    end

endmodule