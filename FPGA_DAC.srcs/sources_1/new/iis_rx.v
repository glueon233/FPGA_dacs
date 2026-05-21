module iis_rx (
    input  wire        clk,        // 24.576MHz
    input  wire        rst_n,      // 明确为低电平有效复位
    input  wire        ws,         
    input  wire        bclk,       
    input  wire        sdata,      
    
    output reg [15:0] l_pcm,
    output reg [15:0] r_pcm,
    output reg        data_valid   // 此时是完美的 1 个 clk 周期脉冲
);

    // 1. 跨时钟域同步 (保持你原来的 CDC 部分，修正复位)
    reg [2:0] bclk_sync, ws_sync, sdata_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bclk_sync  <= 3'b0;
            ws_sync    <= 3'b0;
            sdata_sync <= 3'b0;
        end else begin
            bclk_sync  <= {bclk_sync[1:0], bclk};
            ws_sync    <= {ws_sync[1:0], ws};
            sdata_sync <= {sdata_sync[1:0], sdata};
        end
    end

    // 边沿检测
    wire bclk_rise = (bclk_sync[2:1] == 2'b01);
    wire ws_edge   = (ws_sync[2] ^ ws_sync[1]);

    // 2. 接收逻辑 (全部移入 clk 时钟域)
    reg [5:0]  bit_cnt;
    reg [15:0] l_data_reg, r_data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt    <= 6'd0;
            l_data_reg <= 16'd0;
            r_data_reg <= 16'd0;
            l_pcm      <= 16'd0;
            r_pcm      <= 16'd0;
            data_valid <= 1'b0;
        end else begin
            data_valid <= 1'b0; // 默认拉低

            if (ws_edge) begin
                bit_cnt <= 6'd0; // 左右声道切换时，计数器清零
            end 
            else if (bclk_rise) begin
                bit_cnt <= bit_cnt + 1'b1;

                // 假设数据在 32-bit slot 的前 16 位 (I2S 标准)
                // 注意：I2S 标准中，ws 变化后的第一个 bclk 上升沿是空位，第二个才是 MSB
                if (bit_cnt >= 6'd1 && bit_cnt <= 6'd16) begin
                    if (ws_sync[1] == 1'b0) // 当前是左声道
                        l_data_reg <= {l_data_reg[14:0], sdata_sync[1]};
                    else                    // 当前是右声道
                        r_data_reg <= {r_data_reg[14:0], sdata_sync[1]};
                end

                // 当右声道 32 位全部跑完（或者数到第 16 位拿全数据）时触发 valid
                // 这里建议数到 32 结束，确保一帧数据完整
                if (ws_sync[1] == 1'b1 && bit_cnt == 6'd31) begin
                    l_pcm      <= l_data_reg;
                    r_pcm      <= r_data_reg;
                    data_valid <= 1'b1; // 这里的脉冲宽度等于 1 个 clk 周期
                end
            end
        end
    end

endmodule