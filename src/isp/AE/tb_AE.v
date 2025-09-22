`timescale 1ns/1ps

module tb_AE_Histogramm();

// 参数定义（与被测模块一致）
parameter rgb_width = 8;
parameter resolution_long = 1280;
parameter resolution_width = 720;
parameter hist_bins = 256;
parameter time_step = 16;
parameter gain_step = 8;

// 输入信号
reg clk;
reg rst;
reg [rgb_width-1:0] rgb_r;
reg [rgb_width-1:0] rgb_g;
reg [rgb_width-1:0] rgb_b;
reg rgb_vsync;
reg rgb_valid;

// 输出信号
wire post_valid;
wire [15:0] exposure_time;
wire [15:0] exposure_gain;

// 被测模块实例化
AE_Histogramm #(
    .rgb_width(rgb_width),
    .resolution_long(resolution_long),
    .resolution_width(resolution_width),
    .hist_bins(hist_bins),
    .time_step(time_step),
    .gain_step(gain_step)
) uut (
    .clk(clk),
    .rst(rst),
    .rgb_r(rgb_r),
    .rgb_b(rgb_b),
    .rgb_g(rgb_g),
    .rgb_vsync(rgb_vsync),
    .rgb_valid(rgb_valid),
    .post_valid(post_valid),
    .exposure_time(exposure_time),
    .exposure_gain(exposure_gain)
);

// 时钟生成
initial begin
    clk = 0;
    forever #10 clk = ~clk;  // 50MHz时钟
end

// 测试序列
initial begin
    // 初始化
    rst = 0;
    rgb_r = 0;
    rgb_g = 0;
    rgb_b = 0;
    rgb_vsync = 0;
    rgb_valid = 0;
    
    // 释放复位
    #100;
    rst = 1;
    #20;
    
    // 测试场景1: 图像偏暗（大部分像素为暗区）
    send_frame(8'd30, 8'd30, 8'd30);  // 暗像素(RGB=30,30,30)
    send_frame(8'd30, 8'd30, 8'd30);  // 暗像素(RGB=30,30,30)
    #1000;
    
    // 测试场景2: 图像偏亮（大部分像素为亮区）
    send_frame(8'd230, 8'd230, 8'd230);  // 亮像素(RGB=230,230,230)
    #1000;
    
    // 测试场景3: 图像亮度适中（大部分像素为中间区）
    send_frame(8'd128, 8'd128, 8'd128);  // 中间亮度像素
    #1000;
    
    // 结束仿真
    $stop;
end

// 发送一帧图像的任务
task send_frame;
    input [7:0] r_val;
    input [7:0] g_val;
    input [7:0] b_val;
    integer i;
begin
    // 发送场同步信号
    rgb_vsync = 0;
    #20;
    rgb_vsync = 1;
    #20;
    
    // 发送图像数据（简化为发送1000个有效像素，实际应发送1280*720个）
    for(i = 0; i < 1000; i = i + 1) begin
        rgb_valid = 1;
        rgb_r = r_val;
        rgb_g = g_val;
        rgb_b = b_val;
        #20;
    end
    
    // 结束帧数据
    rgb_valid = 0;
    #20;
end
endtask



endmodule