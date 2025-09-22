module AE_Histogramm #(
parameter rgb_width = 8,
parameter resolution_long = 1280,
parameter resolution_width = 720,
parameter hist_bins = 256,
parameter time_step = 16,
parameter gain_step = 8
)(
input wire clk,
input wire rst,
input wire [rgb_width-1:0] rgb_r,
input wire [rgb_width-1:0] rgb_b,
input wire [rgb_width-1:0] rgb_g,
input wire rgb_vsync,
input wire rgb_valid,
output reg post_valid,
output reg [15:0]exposure_time,
output reg [15:0]exposure_gain
);
//亮度计算模块
reg [15:0] britval;
wire [15:0] rgb_r_b,rgb_g_b,rgb_b_b;
assign {rgb_r_b,rgb_g_b,rgb_b_b}={{8{1'b0}},rgb_r,{8{1'b0}},rgb_g,{8{1'b0}},rgb_b};
always@(posedge clk or negedge rst)begin   
      if(~rst) britval<=0;
      else if(rgb_valid) begin
      britval<= ((rgb_r_b<<6)+(rgb_r_b<<2)+(rgb_r_b<<3)+
      (rgb_b_b<<2)+(rgb_b_b<<3)+(rgb_b_b<<4)+rgb_b_b+(rgb_g_b<<1)
      +(rgb_g_b<<2)+(rgb_g_b<<4)+(rgb_g_b<<7))>>8;//各像素点亮度计算
      end
end
//直方图技术模块直接统计三个区块的像素点数
reg [19:0] dark_pixel_cnt;
reg [19:0] middle_pixel_cnt;
reg [19:0] brit_pixel_cnt;
reg [19:0] dark_pixel;
reg [19:0] middle_pixel;
reg [19:0] brit_pixel;
reg vsync_t1;

always@(posedge clk or negedge rst)begin
   if(~rst) vsync_t1<=0; 
   else begin
   vsync_t1<=rgb_vsync;
   end
end

wire posedge_vsync=(~vsync_t1) & rgb_vsync;//场同步信号下降沿：场同步开始信号

reg cout_done;

always@(posedge clk or negedge rst)begin
    if(~rst)begin
        dark_pixel_cnt <= 0;
        middle_pixel_cnt <= 0;
        brit_pixel_cnt <= 0;
        dark_pixel <= 0;
        middle_pixel <= 0;
        brit_pixel <= 0;
        cout_done<=0;
    end
    else begin if(posedge_vsync)begin
           dark_pixel<=dark_pixel_cnt;
           middle_pixel<=middle_pixel_cnt;
           brit_pixel<=brit_pixel_cnt;
           dark_pixel_cnt<=0;
           middle_pixel_cnt<=0;
           brit_pixel_cnt<=0;
           cout_done<=1;
        end
        else if(rgb_valid)begin
           if(britval < 32) dark_pixel_cnt<=dark_pixel_cnt+1;
           else if(britval>31 & britval<224) middle_pixel_cnt<=middle_pixel_cnt+1;
           else brit_pixel_cnt<=brit_pixel_cnt+1;
           cout_done<=0;
        end
    end   
end//统计各亮度像素个数

reg [1:0] state;
localparam [1:0] IDLE=2'b00;
localparam [1:0] AE_ANAY=2'b01;
localparam [1:0] AE_ADJUST=2'b11;

always@(posedge clk or negedge rst)begin
   if(~rst)begin
      exposure_time<=16'd100;
      exposure_gain<=16'd1;
      state<=IDLE;
      post_valid<=0;
   end 
   else begin
   case(state)
      IDLE:begin
          post_valid<=0;
          if(cout_done)begin
             state<=AE_ANAY;
          end
      end
      AE_ANAY:begin
         if(middle_pixel<552960)begin
            if(dark_pixel>brit_pixel)begin
               state<=AE_ADJUST;
            end else begin
               state<=AE_ADJUST;
            end
         end
         else begin
            post_valid<=1;
            state<=IDLE;
         end
      end
      AE_ADJUST:begin
         if(dark_pixel>brit_pixel)begin
            if(exposure_time<16'd10000)begin
               exposure_time<=exposure_time+time_step;
            end else if(exposure_gain<256)begin
               exposure_gain<=exposure_gain+gain_step;      
            end
         end
         if(dark_pixel<brit_pixel)begin
            if(exposure_time>16'd10)begin
               exposure_time<=exposure_time-time_step;
            end else if(exposure_gain>1)begin
               exposure_gain<=exposure_gain-gain_step;      
            end
         end
      
         post_valid<=1;
         state<=IDLE;
      end
   default:state<=IDLE;
   endcase
   end
end//调整状态机

endmodule
/*`timescale 1ns/1ps

// 假设顶层模块所需的参数和信号定义（根据实际工程补充）
`define CLOCK_MAIN 100_000_000  // 主时钟频率（100MHz）
`define CAMERA_I2C_ADDR 8'h6a   // 摄像头I2C设备地址（与原有代码一致）
`define EXPOSURE_REG 16'h356F   // 曝光时间寄存器地址（参考配置文件）
`define GAIN_REG 16'h358B       // 增益寄存器地址（参考配置文件）

module top_camera_with_AE (
    // 系统时钟与复位
    input wire          clk_sys,         // 系统主时钟（如96MHz/100MHz）
    input wire          rstn_sys,        // 系统复位（低有效）
    
    // 摄像头CSI接口（I2C配置线）
    output reg          csi_scl_o,       // I2C时钟输出
    input wire          csi_sda_i,       // I2C数据输入
    output reg          csi_sda_o,       // I2C数据输出
    output reg          csi_sda_oe,      // I2C数据输出使能
    
    // 摄像头图像数据输入（AE模块的输入）
    input wire [7:0]    rgb_r,           // R通道像素
    input wire [7:0]    rgb_g,           // G通道像素
    input wire [7:0]    rgb_b,           // B通道像素
    input wire          rgb_vsync,       // 图像场同步信号
    input wire          rgb_valid,       // 像素数据有效信号
    
    // 状态输出（可选，用于调试）
    output wire         init_done,       // 摄像头初始化完成标志
    output wire         ae_updating      // AE参数更新中标志
);


// -------------------------- 1. 内部信号定义 --------------------------
// 初始化配置相关信号（复用原有I2C配置模块的信号）
wire [7:0]            init_config_index;  // 初始化配置的LUT索引
wire [23:0]           init_config_data;   // 初始化配置数据（16位寄存器+8位值）
wire [7:0]            init_config_size;   // 初始化配置总条数
wire                  init_config_done;   // 初始化完成标志

// AE动态配置相关信号
reg [7:0]             ae_config_index;    // AE配置的索引（0=曝光，1=增益）
reg [23:0]            ae_config_data;     // AE配置数据（16位寄存器+8位值）
reg [7:0]             ae_config_size;     // AE配置总条数（固定为2：曝光+增益）
reg                   ae_config_start;    // AE配置启动标志
wire                  ae_config_done;     // AE配置完成标志

// AE模块输出信号
wire [15:0]           exposure_time;      // AE计算的曝光时间
wire [15:0]           exposure_gain;      // AE计算的增益
wire                  post_valid;         // AE参数有效标志

// 配置数据源选择信号（0=初始化配置，1=AE动态配置）
reg                   config_sel;         // 0:初始化  1:AE更新


// -------------------------- 2. 模块例化 --------------------------
// 2.1 AE自动曝光模块（你的核心算法模块）
AE_Histogramm #(
    .rgb_width(8),
    .resolution_long(1280),
    .resolution_width(720),
    .hist_bins(256),
    .time_step(16),
    .gain_step(8)
) u_AE_Histogramm (
    .clk(clk_sys),
    .rst(~rstn_sys),  // 注意：AE模块是高电平复位，此处转换为低有效复位
    .rgb_r(rgb_r),
    .rgb_b(rgb_b),
    .rgb_g(rgb_g),
    .rgb_vsync(rgb_vsync),
    .rgb_valid(rgb_valid),
    .post_valid(post_valid),
    .exposure_time(exposure_time),
    .exposure_gain(exposure_gain)
);

// 2.2 摄像头初始化配置LUT模块（原有配置文件）
I2C_AD2020_1280960_FPS60_1Lane_Config u_Init_Config_LUT (
    .LUT_INDEX(init_config_index),
    .LUT_DATA(init_config_data),
    .LUT_SIZE(init_config_size)
);

// 2.3 I2C时序控制器（复用原有模块，支持动态切换配置源）
i2c_timing_ctrl_16bit #(
    .CLK_FREQ(`CLOCK_MAIN),  // 系统时钟频率
    .I2C_FREQ(10_000)        // I2C通信频率（10kHz，与原有一致）
) u_i2c_timing_ctrl_16bit (
    // 全局时钟复位
    .clk(clk_sys),
    .rst_n(rstn_sys),
    
    // I2C物理接口
    .i2c_sclk(csi_scl_o),
    .i2c_sdat_IN(csi_sda_i),
    .i2c_sdat_OUT(csi_sda_o),
    .i2c_sdat_OE(csi_sda_oe),
    
    // I2C配置数据（根据config_sel选择数据源）
    .i2c_config_index(config_sel ? ae_config_index : init_config_index),
    .i2c_config_data(config_sel ? 
                    {`CAMERA_I2C_ADDR, ae_config_data} :  // AE配置：地址+寄存器+值
                    {`CAMERA_I2C_ADDR, init_config_data}), // 初始化配置：地址+寄存器+值
    .i2c_config_size(config_sel ? ae_config_size : init_config_size),
    .i2c_config_done(config_sel ? ae_config_done : init_config_done),
    
    // 原有辅助信号（保持不变）
    .config_clk(w_csi_rx_clk),  // 若未定义，需根据工程补充（如摄像头像素时钟）
    .config_data(config_data),  // 若未定义，可接地或留空（根据模块需求）
    .config_data_valid(config_data_valid)
);


// -------------------------- 3. 核心控制逻辑 --------------------------
// 3.1 配置数据源切换：先初始化，再AE动态更新
always @(posedge clk_sys or negedge rstn_sys) begin
    if (!rstn_sys) begin
        config_sel <= 1'b0;  // 复位后先进入初始化阶段
    end else begin
        // 初始化完成后，切换到AE动态配置模式
        if (init_config_done) begin
            config_sel <= 1'b1;
        end
    end
end

// 3.2 AE动态配置逻辑：当AE参数有效时，发送曝光+增益配置
always @(posedge clk_sys or negedge rstn_sys) begin
    if (!rstn_sys) begin
        ae_config_index <= 8'd0;
        ae_config_data <= 24'd0;
        ae_config_size <= 8'd2;  // 每次AE更新需配置2个寄存器：曝光+增益
        ae_config_start <= 1'b0;
    end else begin
        // 当AE计算出新参数（post_valid为高），启动配置
        if (post_valid && config_sel) begin
            case (ae_config_index)
                8'd0: begin  // 第1条：配置曝光时间
                    ae_config_data <= {`EXPOSURE_REG, exposure_time[7:0]};  // 寄存器+曝光值（8位，需根据摄像头调整）
                    ae_config_index <= 8'd1;
                end
                8'd1: begin  // 第2条：配置增益
                    ae_config_data <= {`GAIN_REG, exposure_gain[7:0]};      // 寄存器+增益值（8位，需根据摄像头调整）
                    ae_config_index <= 8'd0;  // 复位索引，等待下一次更新
                    ae_config_start <= 1'b1;  // 启动I2C发送
                end
            endcase
        end else if (ae_config_done) begin
            ae_config_start <= 1'b0;  // 发送完成后复位启动标志
        end
    end
end


// -------------------------- 4. 状态输出（调试用） --------------------------
assign init_done = init_config_done;          // 初始化完成标志
assign ae_updating = post_valid && config_sel; // AE参数更新中标志


// -------------------------- 5. 补充说明 --------------------------
// （1）若摄像头的曝光/增益寄存器为16位，需修改ae_config_data的格式：
// ae_config_data <= {`EXPOSURE_REG[15:8], `EXPOSURE_REG[7:0], exposure_time[15:8], exposure_time[7:0]};
// 同时需确认i2c_timing_ctrl_16bit模块是否支持32位配置数据（或修改模块支持）。

// （2）w_csi_rx_clk、config_data、config_data_valid若未定义：
// - 若摄像头输出像素时钟，可连接到w_csi_rx_clk；
// - 若模块不需要这些信号，可在模块内部接地（需修改i2c_timing_ctrl_16bit）。

// （3）I2C地址`CAMERA_I2C_ADDR`需与摄像头硬件一致（原有代码为8'h6a，保持不变）。

endmodule*/