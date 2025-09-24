`timescale 1ns/1ps
////////////////////////////////////////////////////////////////////////////////
// 模块名称: VIP_Matrix_Generate_3X3_8Bit
// 功能: 生成3x3像素矩阵窗口，适用于高斯滤波等图像处理
////////////////////////////////////////////////////////////////////////////////
module VIP_Matrix_Generate_3X3_8Bit_fff(
    input               clk,
    input               rst_n,
    input               per_frame_vsync,
    input               per_frame_href,
    input               per_frame_hsync,
    input       [7:0]   per_img_Y,           // 输入像素

    output reg  [7:0]   matrix_p11, matrix_p12, matrix_p13,
    output reg  [7:0]   matrix_p21, matrix_p22, matrix_p23,
    output reg  [7:0]   matrix_p31, matrix_p32, matrix_p33,
    output reg          matrix_frame_vsync,
    output reg          matrix_frame_href,
    output reg          matrix_frame_hsync
);

////////////////////////////////////////////////////////////////////////////////
// 行缓存（两行），用于保存前两行像素
////////////////////////////////////////////////////////////////////////////////
reg [7:0] line_buffer1 [0:2047]; // 假设最大行宽2048
reg [7:0] line_buffer2 [0:2047];
reg [11:0] col_cnt;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        col_cnt <= 0;
    else if(per_frame_href)
        col_cnt <= col_cnt + 1;
    else
        col_cnt <= 0;
end

// 写入行缓存
always @(posedge clk) begin
    if(per_frame_href) begin
        line_buffer1[col_cnt] <= per_img_Y;
        line_buffer2[col_cnt] <= line_buffer1[col_cnt];
    end
end

////////////////////////////////////////////////////////////////////////////////
// 3x3窗口输出
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// 像素移位（用于第三行）
////////////////////////////////////////////////////////////////////////////////
reg [7:0] per_img_Y_prev1, per_img_Y_next1;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        per_img_Y_prev1 <= 0;
        per_img_Y_next1 <= 0;
    end else begin
        per_img_Y_prev1 <= per_img_Y;
        per_img_Y_next1 <= per_img_Y_prev1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        matrix_p11 <= 0; matrix_p12 <= 0; matrix_p13 <= 0;
        matrix_p21 <= 0; matrix_p22 <= 0; matrix_p23 <= 0;
        matrix_p31 <= 0; matrix_p32 <= 0; matrix_p33 <= 0;
        matrix_frame_vsync <= 0;
        matrix_frame_href  <= 0;
        matrix_frame_hsync <= 0;
    end else begin
        // 第一行
        matrix_p11 <= line_buffer2[col_cnt-1];
        matrix_p12 <= line_buffer2[col_cnt];
        matrix_p13 <= line_buffer2[col_cnt+1];
        // 第二行
        matrix_p21 <= line_buffer1[col_cnt-1];
        matrix_p22 <= line_buffer1[col_cnt];
        matrix_p23 <= line_buffer1[col_cnt+1];
        // 第三行
        matrix_p31 <= per_img_Y_prev1;
        matrix_p32 <= per_img_Y;
        matrix_p33 <= per_img_Y_next1;

        // 时序信号同步
        matrix_frame_vsync <= per_frame_vsync;
        matrix_frame_href  <= per_frame_href;
        matrix_frame_hsync <= per_frame_hsync;
    end
end

endmodule