`timescale 1ns/1ns
`define SIM_CLOCK_FREQ  25_000_000  // 仿真时钟频率：25MHz（对应40ns周期）
`define SIM_IMG_HDISP   640         // 仿真图像宽度：640像素
`define SIM_IMG_VDISP   480         // 仿真图像高度：480像素
`define SIM_MIRROR_MODE 2'b00       // 镜像模式（00/01/10/11，对应不同Bayer阵列）

module tb_VIP_RAW8_RGB888;

// -------------------------- 1. 信号定义 --------------------------
// 全局时钟与复位
reg                     clk;
reg                     rst_n;

// 输入：RAW 数据与时序（模拟CMOS传感器输出）
reg [1:0]               mirror;                  // 镜像模式控制
reg                     per_frame_vsync;         // 输入场同步信号
reg                     per_frame_href;          // 输入行有效信号
reg                     per_frame_hsync;         // 输入行同步信号
reg [7:0]               per_img_RAW;             // 输入8bit RAW数据

// 输出：RGB888 数据与时序（待验证信号）
wire                    post_frame_vsync;        // 输出场同步信号
wire                    post_frame_href;         // 输出行有效信号
wire                    post_frame_hsync;        // 输出行同步信号
wire [7:0]              post_img_red;            // 输出红色通道
wire [7:0]              post_img_green;          // 输出绿色通道
wire [7:0]              post_img_blue;           // 输出蓝色通道

// 内部计数信号（用于生成时序）
reg [13:0]              line_cnt;                // 行计数器（0~IMG_VDISP-1）
reg [13:0]              pixel_cnt;               // 像素计数器（0~IMG_HDISP-1）
reg [3:0]               vsync_cnt;               // 场同步周期计数器（控制VSYNC脉冲宽度）


// -------------------------- 2. 实例化待测试模块 --------------------------
VIP_RAW8_RGB888
#(
    .IMG_HDISP    (`SIM_IMG_HDISP),  // 配置图像宽度
    .IMG_VDISP    (`SIM_IMG_VDISP)   // 配置图像高度
)
u_DUT  // DUT (Design Under Test)：待测试模块
(
    // 全局时钟与复位
    .clk                (clk),
    .rst_n              (rst_n),
    .mirror             (mirror),

    // 输入：RAW 数据与时序
    .per_frame_vsync    (per_frame_vsync),
    .per_frame_href     (per_frame_href),
    .per_frame_hsync    (per_frame_hsync),
    .per_img_RAW        (per_img_RAW),

    // 输出：RGB888 数据与时序
    .post_frame_vsync   (post_frame_vsync),
    .post_frame_href    (post_frame_href),
    .post_frame_hsync   (post_frame_hsync),
    .post_img_red       (post_img_red),
    .post_img_green     (post_img_green),
    .post_img_blue      (post_img_blue)
);


// -------------------------- 3. 生成仿真时钟 --------------------------
initial begin
    clk = 1'b0;
    forever #20 clk = ~clk;
end


// -------------------------- 4. 生成复位信号 --------------------------
initial begin
    rst_n = 1'b0;  // 初始复位
     #200;     // 复位200ns（5个时钟周期，确保稳定复位）
    rst_n = 1'b1;  // 释放复位
end


// -------------------------- 5. 配置镜像模式 --------------------------
initial begin
    mirror = `SIM_MIRROR_MODE;  // 仿真开始时配置镜像模式，可根据需求修改
    $display("=============================================");
    $display("仿真配置：");
    $display(" - 时钟频率：%0d MHz", `SIM_CLOCK_FREQ / 1_000_000);
    $display(" - 图像分辨率：%0d x %0d", `SIM_IMG_HDISP, `SIM_IMG_VDISP);
    $display(" - 镜像模式：%b", `SIM_MIRROR_MODE);
    $display("=============================================\n");
end


// -------------------------- 6. 生成 CMOS 时序与 RAW 数据 --------------------------
// 6.1 场同步（VSYNC）生成：每帧开始时输出低电平脉冲（持续4个时钟周期）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        per_frame_vsync <= 1'b1;  // VSYNC默认高电平（无效）
        vsync_cnt <= 4'd0;
    end else begin
        // 当一行结束且是最后一行时，触发VSYNC
        if (line_cnt == `SIM_IMG_VDISP - 1 && pixel_cnt == `SIM_IMG_HDISP - 1) begin
            vsync_cnt <= 4'd1;
            per_frame_vsync <= 1'b0;  // VSYNC拉低（有效）
        end else if (vsync_cnt > 0 && vsync_cnt < 4'd4) begin
            vsync_cnt <= vsync_cnt + 1'b1;
            per_frame_vsync <= 1'b0;  // 保持VSYNC有效
        end else begin
            vsync_cnt <= 4'd0;
            per_frame_vsync <= 1'b1;  // VSYNC恢复高电平（无效）
        end
    end
end

// 6.2 行同步（HSYNC）生成：每行开始时输出低电平脉冲（持续2个时钟周期）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        per_frame_hsync <= 1'b1;  // HSYNC默认高电平（无效）
    end else begin
        // 像素计数到行尾，或VSYNC有效时，触发HSYNC
        if (pixel_cnt == `SIM_IMG_HDISP - 1 || per_frame_vsync == 1'b0) begin
            per_frame_hsync <= 1'b0;  // HSYNC拉低（有效）
        end else if (pixel_cnt == 4'd1) begin
            per_frame_hsync <= 1'b1;  // 2个时钟后恢复高电平
        end
    end
end

// 6.3 行有效（HREF）生成：每行像素期间输出高电平（有效）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        per_frame_href <= 1'b0;  // HREF默认低电平（无效）
    end else begin
        // 像素计数在 2~IMG_HDISP+1 期间，HREF有效（避开HSYNC脉冲）
        if (pixel_cnt >= 4'd2 && pixel_cnt <= `SIM_IMG_HDISP + 1) begin
            per_frame_href <= 1'b1;
        end else begin
            per_frame_href <= 1'b0;
        end
    end
end

// 6.4 像素计数器（控制每行像素数）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_cnt <= 14'd0;
    end else begin
        // VSYNC有效时，重置像素计数
        if (per_frame_vsync == 1'b0) begin 
            pixel_cnt<=0;
        end else begin
            pixel_cnt <= pixel_cnt + 1'b1;
            // 计数到行尾（包含HSYNC和无效像素），重置计数
            if (pixel_cnt == `SIM_IMG_HDISP + 4'd4) begin
                pixel_cnt <= 14'd0;
            end
        end
    end
end

// 6.5 行计数器（控制每帧行数）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        line_cnt <= 14'd0;
    end else begin
        // VSYNC有效时，重置行计数
        if (per_frame_vsync == 1'b0) begin
            line_cnt <= 14'd0;
        end else if (pixel_cnt == `SIM_IMG_HDISP + 4'd4) begin
            // 每行结束时，行计数+1；到最后一行时重置
            line_cnt <= (line_cnt == `SIM_IMG_VDISP - 1) ? 14'd0 : line_cnt + 1'b1;
        end
    end
end

// 6.6 生成 8bit RAW 数据（模拟 Bayer 阵列，按行奇偶/像素奇偶分配）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        per_img_RAW <= 8'd0;
    end else if (per_frame_href == 1'b1) begin
        // 按行奇偶（line_cnt[0]）和像素奇偶（pixel_cnt[0]）分配RAW数据
        case ({line_cnt[0], pixel_cnt[0]})
            2'b00: per_img_RAW <= 8'd100;  // 偶数行+偶像素：B（蓝色）
            2'b01: per_img_RAW <= 8'd150;  // 偶数行+奇像素：G（绿色）
            2'b10: per_img_RAW <= 8'd150;  // 奇数行+偶像素：G（绿色）
            2'b11: per_img_RAW <= 8'd200;  // 奇数行+奇像素：R（红色）
        endcase
    end else begin
        per_img_RAW <= 8'd0;  // HREF无效时，RAW数据置0
    end
end



reg [1:0] per_frame_vsync_dly;  // 输入VSYNC延迟寄存器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        per_frame_vsync_dly <= 2'b11;
    end else begin
        per_frame_vsync_dly <= {per_frame_vsync_dly[0], per_frame_vsync};
    end
end

// 检查输出VSYNC与输入VSYNC的同步性
always @(posedge clk) begin
    if (rst_n == 1'b1) begin
        if (post_frame_vsync !== per_frame_vsync_dly[1]) begin
            $warning("[%0t ns] 时序警告：输出VSYNC与输入VSYNC延迟不匹配！", $time);
        end
    end
end



endmodule