`timescale 1ns/1ps
////////////////////////////////////////////////////////////////////////////////
// 模块名称: GaussianHighlightSuppressor
// 功能: 对输入的RGB888图像数据进行高光消除，只在高光区域进行3x3高斯滤波
// 时序: 支持标准视频同步信号（vsync、hsync、href）
// 说明: 需配合3x3矩阵生成模块（如VIP_Matrix_Generate_3X3_8Bit）使用
////////////////////////////////////////////////////////////////////////////////
module GaussianHighlightSuppressor #(
    parameter DATA_WIDTH = 8,
    parameter THRESHOLD  = 220 // 高光阈值
)(
    input                   clk,                // 时钟信号（90MHz）
    input                   rst_n,              // 异步复位信号

    // 输入时序信号
    input                   per_frame_vsync,    // 输入帧同步
    input                   per_frame_hsync,    // 输入行同步
    input                   per_frame_href,     // 输入行有效

    // 输入RGB888数据
    input   [DATA_WIDTH-1:0] per_img_red,       // 输入红色分量
    input   [DATA_WIDTH-1:0] per_img_green,     // 输入绿色分量
    input   [DATA_WIDTH-1:0] per_img_blue,      // 输入蓝色分量

    // 输出时序信号
    output                   post_matrix_frame_vsync,   // 输出帧同步
    output                   post_matrix_frame_href,   // 输出行同步
    output                  post_matrix_frame_hsync,    // 输出行有效

    // 输出RGB888数据
    output reg  [DATA_WIDTH-1:0] post_img_red,      // 输出红色分量
    output reg  [DATA_WIDTH-1:0] post_img_green,    // 输出绿色分量
    output reg  [DATA_WIDTH-1:0] post_img_blue      // 输出蓝色分量
);

////////////////////////////////////////////////////////////////////////////////
// 3x3矩阵生成模块实例化（红色通道）
////////////////////////////////////////////////////////////////////////////////
wire [DATA_WIDTH-1:0] matrix_r11, matrix_r12, matrix_r13;
wire [DATA_WIDTH-1:0] matrix_r21, matrix_r22, matrix_r23;
wire [DATA_WIDTH-1:0] matrix_r31, matrix_r32, matrix_r33;

VIP_Matrix_Generate_3X3_8Bit u_R_Matrix (
    .clk(clk),
    .rst_n(rst_n),
    .per_frame_vsync(per_frame_vsync),
    .per_frame_href(per_frame_href),
    .per_frame_hsync(per_frame_hsync),
    .per_img_Y(per_img_red),
    .matrix_p11(matrix_r11), .matrix_p12(matrix_r12), .matrix_p13(matrix_r13),
    .matrix_p21(matrix_r21), .matrix_p22(matrix_r22), .matrix_p23(matrix_r23),
    .matrix_p31(matrix_r31), .matrix_p32(matrix_r32), .matrix_p33(matrix_r33),
    .matrix_frame_vsync(), .matrix_frame_href(), .matrix_frame_hsync()
);

////////////////////////////////////////////////////////////////////////////////
// 3x3矩阵生成模块实例化（绿色通道）
////////////////////////////////////////////////////////////////////////////////
wire [DATA_WIDTH-1:0] matrix_g11, matrix_g12, matrix_g13;
wire [DATA_WIDTH-1:0] matrix_g21, matrix_g22, matrix_g23;
wire [DATA_WIDTH-1:0] matrix_g31, matrix_g32, matrix_g33;

VIP_Matrix_Generate_3X3_8Bit u_G_Matrix (
    .clk(clk),
    .rst_n(rst_n),
    .per_frame_vsync(per_frame_vsync),
    .per_frame_href(per_frame_href),
    .per_frame_hsync(per_frame_hsync),
    .per_img_Y(per_img_green),
    .matrix_p11(matrix_g11), .matrix_p12(matrix_g12), .matrix_p13(matrix_g13),
    .matrix_p21(matrix_g21), .matrix_p22(matrix_g22), .matrix_p23(matrix_g23),
    .matrix_p31(matrix_g31), .matrix_p32(matrix_g32), .matrix_p33(matrix_g33),
    .matrix_frame_vsync(), .matrix_frame_href(), .matrix_frame_hsync()
);

////////////////////////////////////////////////////////////////////////////////
// 3x3矩阵生成模块实例化（蓝色通道）
////////////////////////////////////////////////////////////////////////////////
wire [DATA_WIDTH-1:0] matrix_b11, matrix_b12, matrix_b13;
wire [DATA_WIDTH-1:0] matrix_b21, matrix_b22, matrix_b23;
wire [DATA_WIDTH-1:0] matrix_b31, matrix_b32, matrix_b33;

VIP_Matrix_Generate_3X3_8Bit u_B_Matrix (
    .clk(clk),
    .rst_n(rst_n),
    .per_frame_vsync(per_frame_vsync),
    .per_frame_href(per_frame_href),
    .per_frame_hsync(per_frame_hsync),
    .per_img_Y(per_img_blue),
    .matrix_p11(matrix_b11), .matrix_p12(matrix_b12), .matrix_p13(matrix_b13),
    .matrix_p21(matrix_b21), .matrix_p22(matrix_b22), .matrix_p23(matrix_b23),
    .matrix_p31(matrix_b31), .matrix_p32(matrix_b32), .matrix_p33(matrix_b33),
    .matrix_frame_vsync(), .matrix_frame_href(), .matrix_frame_hsync()
);

////////////////////////////////////////////////////////////////////////////////
// 高斯核权重定义（3x3，归一化系数为16）
////////////////////////////////////////////////////////////////////////////////
localparam [3:0] G11=1, G12=2, G13=1;
localparam [3:0] G21=2, G22=4, G23=2;
localparam [3:0] G31=1, G32=2, G33=1;

////////////////////////////////////////////////////////////////////////////////
// 高斯滤波计算（红色通道）
////////////////////////////////////////////////////////////////////////////////
wire [15:0] red_gauss_sum =
    matrix_r11*G11 + matrix_r12*G12 + matrix_r13*G13 +
    matrix_r21*G21 + matrix_r22*G22 + matrix_r23*G23 +
    matrix_r31*G31 + matrix_r32*G32 + matrix_r33*G33;

wire [7:0] post_img_red_gauss = red_gauss_sum[11:4]; // 除以16，取高位

////////////////////////////////////////////////////////////////////////////////
// 高斯滤波计算（绿色通道）
////////////////////////////////////////////////////////////////////////////////
wire [15:0] green_gauss_sum =
    matrix_g11*G11 + matrix_g12*G12 + matrix_g13*G13 +
    matrix_g21*G21 + matrix_g22*G22 + matrix_g23*G23 +
    matrix_g31*G31 + matrix_g32*G32 + matrix_g33*G33;

wire [7:0] post_img_green_gauss = green_gauss_sum[11:4]; // 除以16，取高位

////////////////////////////////////////////////////////////////////////////////
// 高斯滤波计算（蓝色通道）
////////////////////////////////////////////////////////////////////////////////
wire [15:0] blue_gauss_sum =
    matrix_b11*G11 + matrix_b12*G12 + matrix_b13*G13 +
    matrix_b21*G21 + matrix_b22*G22 + matrix_b23*G23 +
    matrix_b31*G31 + matrix_b32*G32 + matrix_b33*G33;

wire [7:0] post_img_blue_gauss = blue_gauss_sum[11:4]; // 除以16，取高位

////////////////////////////////////////////////////////////////////////////////
// 高光检测
////////////////////////////////////////////////////////////////////////////////
wire is_highlight = (per_img_red > THRESHOLD) || (per_img_green > THRESHOLD) || (per_img_blue > THRESHOLD);

////////////////////////////////////////////////////////////////////////////////
// 输出选择：高光区域进行高斯滤波，否则保持原始像素值
////////////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        post_img_red   <= 0;
        post_img_green <= 0;
        post_img_blue  <= 0;
    end else begin
        if(is_highlight) begin
            post_img_red   <= post_img_red_gauss;
            post_img_green <= post_img_green_gauss;
            post_img_blue  <= post_img_blue_gauss;
        end else begin
            post_img_red   <= per_img_red;
            post_img_green <= per_img_green;
            post_img_blue  <= per_img_blue;
        end
    end
end

//------------------------------------------
//lag 2 clocks signal sync  
reg [2:0]   per_frame_vsync_r;
reg [2:0]   per_frame_href_r;   
reg [2:0]   per_frame_hsync_r; 
reg [2:0]   per_frame_clken_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
        per_frame_vsync_r <= 0;
        per_frame_href_r <= 0;
	  per_frame_hsync_r <= 0; 
        end
    else
        begin
        per_frame_vsync_r   <=  {per_frame_vsync_r[1:0],    per_frame_vsync};
        per_frame_href_r    <=  {per_frame_href_r[1:0],     per_frame_href};
	  per_frame_hsync_r   <=  {per_frame_hsync_r[1:0],    per_frame_hsync}; 
        end
end
//Give up the 1th and 2th row edge data caculate for simple process
//Give up the 1th and 2th point of 1 line for simple process
wire    read_frame_href     =   per_frame_href_r[0]|per_frame_href_r[1];    //RAM read href sync signal
assign  post_matrix_frame_vsync  =   per_frame_vsync_r[2];
assign  post_matrix_frame_href   =   per_frame_href_r[2];
assign  post_matrix_frame_hsync  =   per_frame_hsync_r[2]; 
endmodule