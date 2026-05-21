module audio_top_v3 (
    input  wire clk,
    input  wire rst_n,
    
    // I2S
    input  wire iis_bclk,
    input  wire iis_lrclk,
    input  wire iis_sdata,

    // 输出（4x PCM）
    output wire rout,
    output wire lout
);

wire sclk;
wire locked;

clk_wiz_0 pll (
    .clk_out1(sclk),
    .reset(~rst_n),
    .locked(locked),
    .clk_in1(clk)
);
//24.572M

wire rst_sync_n = rst_n & locked;

//////////////////////////////////////////////////
// 2. I2S 接收（1x）
//////////////////////////////////////////////////

wire [15:0] l_1x, r_1x;
wire        valid_1x;

iis_rx iis_inst (
    .clk(sclk),
    .rst_n(rst_sync_n),
    .ws(iis_lrclk),
    .bclk(iis_bclk),
    .sdata(iis_sdata),
    .l_pcm(l_1x),
    .r_pcm(r_1x),
    .data_valid(valid_1x)
);

//////////////////////////////////////////////////
// 3. 1x → 2x（AXIS规范）
//////////////////////////////////////////////////

wire        ready_1x_l, ready_1x_r;
wire [23:0] l_2x, r_2x;
wire        valid_2x_l, valid_2x_r;

// 左
fir_compiler_0 fir_l_2x (
    .aclk(sclk),
    .s_axis_data_tvalid(valid_1x),
    .s_axis_data_tready(ready_1x_l),
    .s_axis_data_tdata(l_1x),
    .m_axis_data_tvalid(valid_2x_l),
    .m_axis_data_tdata(l_2x)
);

// 右
fir_compiler_0 fir_r_2x (
    .aclk(sclk),
    .s_axis_data_tvalid(valid_1x),
    .s_axis_data_tready(ready_1x_r),
    .s_axis_data_tdata(r_1x),
    .m_axis_data_tvalid(valid_2x_r),
    .m_axis_data_tdata(r_2x)
);

//////////////////////////////////////////////////
// 4. 2x → 4x
//////////////////////////////////////////////////

wire [23:0] l_4x, r_4x;
wire        valid_4x_l, valid_4x_r,valid_4x;

fir_compiler_1 fir_l_4x (
    .aclk(sclk),
    .s_axis_data_tvalid(valid_2x_l),
    .s_axis_data_tready(),
    .s_axis_data_tdata(l_2x),
    .m_axis_data_tvalid(valid_4x_l),
    .m_axis_data_tdata(l_4x)
);

fir_compiler_1 fir_r_4x (
    .aclk(sclk),
    .s_axis_data_tvalid(valid_2x_r),
    .s_axis_data_tready(),
    .s_axis_data_tdata(r_2x),
    .m_axis_data_tvalid(valid_4x_r),
    .m_axis_data_tdata(r_4x)
);

//////////////////////////////////////////////////
// 5. 对齐与同步
//////////////////////////////////////////////////

// 用左声道作为主valid（避免AND导致丢数）
/*
reg valid_4x_reg;
always @(posedge sclk or negedge rst_sync_n) begin
    if (!rst_sync_n)
        valid_4x_reg <= 0;
    else
        valid_4x_reg <= valid_4x_l;
end

assign valid_4x = valid_4x_reg;
*/

wire [23:0] l_64x_data, r_64x_data;
wire        valid_64x_l, valid_64x_r;



fir_compiler_2 fir_l_64x (
    .aclk(sclk),
    .s_axis_data_tvalid(valid_4x_l),
    .s_axis_data_tready(),
    .s_axis_data_tdata(l_4x), 
    .m_axis_data_tvalid(valid_64x_l),
    .m_axis_data_tdata(l_64x_data)
);

fir_compiler_2 fir_r_64x (
    .aclk(sclk),
    .s_axis_data_tvalid(valid_4x_r),
    .s_axis_data_tready(),
    .s_axis_data_tdata(r_4x), 
    .m_axis_data_tvalid(valid_64x_r),
    .m_axis_data_tdata(r_64x_data)
);

wire l_o,r_o;
wire signed [19:0] l_sdm_in;
wire signed [19:0] r_sdm_in;

assign l_sdm_in = l_64x_data[23:4];
assign r_sdm_in = r_64x_data[23:4];
/*
wire [15:0] l_256x_data, r_256x_data;
wire        valid_256x_l, valid_256x_r;
fir_compiler_3 fir_l_256x (
    .aclk(sclk),
    .s_axis_data_tvalid(valid_4x),
    .s_axis_data_tready(),
    .s_axis_data_tdata(l_4x), 
    .m_axis_data_tvalid(valid_256x_l),
    .m_axis_data_tdata(l_256x_data)
);

fir_compiler_3 fir_r_256x (
    .aclk(sclk),
    .s_axis_data_tvalid(valid_4x),
    .s_axis_data_tready(),
    .s_axis_data_tdata(r_4x), 
    .m_axis_data_tvalid(valid_256x_r),
    .m_axis_data_tdata(r_256x_data)
);
*/

/*
sdm_2nd sdm_R(
    .clk(sclk),
    .rst_n(rst_sync_n),
    .pcm_in(r_sdm_in),
    .pdm_out(r_o)
);
sdm_2nd sdm_L(
    .clk(sclk),
    .rst_n(rst_sync_n),
    .pcm_in(l_sdm_in),
    .pdm_out(l_o)
);
*/

sdm_1o sdm_R(
.clk(sclk),      
.rst_n(rst_sync_n),
.din(r_64x_data),  
.valid(valid_64x_r),    
.dout(r_o)     
);
sdm_1o sdm_L(
.clk(sclk),      
.rst_n(rst_sync_n),
.din(l_64x_data),  
.valid(valid_64x_l),    
.dout(l_o)     
);


assign rout = r_o;
assign lout = l_o;
endmodule