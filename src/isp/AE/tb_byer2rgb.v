`timescale 1ns/1ns
module tb_VIP_RAW8_RGB888_55;

// -------------------------- 1. 仿真参数定义 --------------------------
// 时钟参数（720p@60Hz标准时钟：74.25MHz，周期≈13.468ns）
localparam CLK_PERIOD    = 13.468;  // 时钟周期(ns)
localparam RST_DURATION  = 10;      // 复位持续时间（时钟周期数）

// 视频时序参数（1280x720@60Hz 标准时序）
localparam H_ACTIVE      = 1280;    // 水平有效像素数
localparam H_SYNC_WIDTH  = 40;      // 水平同步脉宽
localparam H_BACK_PORCH  = 220;     // 水平后肩
localparam H_FRONT_PORCH = 110;     // 水平前肩
localparam H_TOTAL       = H_ACTIVE + H_SYNC_WIDTH + H_BACK_PORCH + H_FRONT_PORCH;  // 水平总周期

localparam V_ACTIVE      = 720;     // 垂直有效行数
localparam V_SYNC_WIDTH  = 5;       // 垂直同步脉宽
localparam V_BACK_PORCH  = 20;      // 垂直后肩
localparam V_FRONT_PORCH = 5;       // 垂直前肩
localparam V_TOTAL       = V_ACTIVE + V_SYNC_WIDTH + V_BACK_PORCH + V_FRONT_PORCH;  // 垂直总周期

// 仿真结束时间（3帧周期，确保覆盖完整功能）
localparam SIM_END_TIME  = 3 * V_TOTAL * H_TOTAL * CLK_PERIOD;


// -------------------------- 2. 信号声明 --------------------------
// 时钟与复位
reg                 clk;
reg                 rst_n;

// 输入信号（RAW数据与控制）
reg  [1:0]          mirror;                  // 镜像控制
reg                 per_frame_vsync;         // 输入帧同步
reg                 per_frame_href;          // 输入行有效
reg                 per_frame_hsync;         // 输入行同步
reg  [7:0]          per_img_RAW;             // 输入8bit RAW数据

// 输出信号（RGB数据与同步）
wire                post_frame_vsync;        // 输出帧同步
wire                post_frame_href;         // 输出行有效
wire                post_frame_hsync;        // 输出行同步
wire [7:0]          post_img_red;            // 输出R通道
wire [7:0]          post_img_green;          // 输出G通道
wire [7:0]          post_img_blue;           // 输出B通道

// 内部时序计数器
reg  [13:0]         h_cnt;  // 水平计数器（0~H_TOTAL-1）
reg  [13:0]         v_cnt;  // 垂直计数器（0~V_TOTAL-1）


// -------------------------- 3. 例化顶层模块 --------------------------
VIP_RAW8_RGB888_55
#(
    .IMG_HDISP(H_ACTIVE),  // 水平有效像素：1280
    .IMG_VDISP(V_ACTIVE)   // 垂直有效像素：720
)
u_VIP_RAW8_RGB888_55
(
    // 全局时钟与复位
    .clk(clk),
    .rst_n(rst_n),
    
    // 镜像控制
    .mirror(mirror),
    
    // 输入RAW数据与同步
    .per_frame_vsync(per_frame_vsync),
    .per_frame_href(per_frame_href),
    .per_frame_hsync(per_frame_hsync),
    .per_img_RAW(per_img_RAW),
    
    // 输出RGB数据与同步
    .post_frame_vsync(post_frame_vsync),
    .post_frame_href(post_frame_href),
    .post_frame_hsync(post_frame_hsync),
    .post_img_red(post_img_red),
    .post_img_green(post_img_green),
    .post_img_blue(post_img_blue)
);


// -------------------------- 4. 激励信号生成 --------------------------
// 4.1 时钟生成（50%占空比）
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// 4.2 复位生成（低电平有效，上电后复位10个时钟周期）
initial begin
    rst_n = 1'b0;
    repeat(RST_DURATION) @(posedge clk);  // 等待10个时钟
    rst_n = 1'b1;
end

// 4.3 镜像模式切换（仿真中覆盖4种模式）
initial begin
    mirror = 2'b00;  // 模式0：无镜像
    #(1 * V_TOTAL * H_TOTAL * CLK_PERIOD);  // 第1帧结束后切换
    mirror = 2'b01;  // 模式1：水平镜像
    #(1 * V_TOTAL * H_TOTAL * CLK_PERIOD);  // 第2帧结束后切换
    mirror = 2'b10;  // 模式2：垂直镜像
    #(1 * V_TOTAL * H_TOTAL * CLK_PERIOD);  // 第3帧结束后保持
    mirror = 2'b11;  // 模式3：水平+垂直镜像
end

// 4.4 视频同步信号生成（vsync/hsync/href）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        h_cnt <= 14'd0;
        v_cnt <= 14'd0;
        per_frame_vsync <= 1'b1;  // vsync高电平无效（标准时序）
        per_frame_hsync <= 1'b1;  // hsync高电平无效（标准时序）
        per_frame_href  <= 1'b0;  // href低电平无效
    end else begin
        // 水平计数器：0~H_TOTAL-1循环
        if(h_cnt == H_TOTAL - 1'b1) begin
            h_cnt <= 14'd0;
            // 垂直计数器：水平周期结束后+1，0~V_TOTAL-1循环
            if(v_cnt == V_TOTAL - 1'b1) begin
                v_cnt <= 14'd0;
            end else begin
                v_cnt <= v_cnt + 1'b1;
            end
        end else begin
            h_cnt <= h_cnt + 1'b1;
        end

        // 1. 水平同步（hsync）：低电平有效，持续H_SYNC_WIDTH个时钟
        if(h_cnt < H_SYNC_WIDTH) begin
            per_frame_hsync <= 1'b0;
        end else begin
            per_frame_hsync <= 1'b1;
        end

        // 2. 行有效（href）：高电平有效，对应水平有效像素区域
        if(h_cnt >= (H_SYNC_WIDTH + H_BACK_PORCH) && 
           h_cnt < (H_SYNC_WIDTH + H_BACK_PORCH + H_ACTIVE)) begin
            per_frame_href <= 1'b1;
        end else begin
            per_frame_href <= 1'b0;
        end

        // 3. 帧同步（vsync）：低电平有效，持续V_SYNC_WIDTH个行周期
        if(v_cnt < V_SYNC_WIDTH) begin
            per_frame_vsync <= 1'b0;
        end else begin
            per_frame_vsync <= 1'b1;
        end
    end
end
reg row_odd;
 reg pixel_odd;
// 4.5 RAW数据生成（Bayer格式：奇数行GRGR，偶数行BGBG）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        per_img_RAW <= 8'd0;
    end else if(per_frame_href) begin  // 行有效期间生成数据
        // 行号奇偶（v_cnt：跳过vsync和前后肩，取有效行的奇偶）
         // 有效行：1=奇数行，0=偶数行
        row_odd = (v_cnt >= (V_SYNC_WIDTH + V_BACK_PORCH)) ? 
                  (v_cnt - (V_SYNC_WIDTH + V_BACK_PORCH)): 1'b0;
        
        // 像素号奇偶（h_cnt：跳过hsync和前后肩，取有效像素的奇偶）
          // 有效像素：1=奇数点，0=偶数点
        pixel_odd = (h_cnt >= (H_SYNC_WIDTH + H_BACK_PORCH)) ? 
                    (h_cnt - (H_SYNC_WIDTH + H_BACK_PORCH)) : 1'b0;

        // Bayer阵列数据分配（渐变数据，便于观察RGB转换结果）
        case({row_odd, pixel_odd})
            2'b11: per_img_RAW <= 8'd200;  // 奇数行+奇数点：R（高亮度）
            2'b10: per_img_RAW <= 8'd150;  // 奇数行+偶数点：G（中亮度）
            2'b01: per_img_RAW <= 8'd100;  // 偶数行+奇数点：G（低亮度）
            2'b00: per_img_RAW <= 8'd50;   // 偶数行+偶数点：B（最低亮度）
        endcase
    end else begin
        per_img_RAW <= 8'd0;  // 行无效时数据为0
    end
end


// -------------------------- 5. 仿真控制与波形Dump --------------------------
// 5.1 波形Dump（生成VCD文件，用于ModelSim波形查看）
initial begin
    $dumpfile("tb_VIP_RAW8_RGB888_55.vcd");  // 波形文件名称
    $dumpvars(0, tb_VIP_RAW8_RGB888_55);     // Dump所有层级信号
end

// 5.2 仿真结束控制（运行SIM_END_TIME后停止）
initial begin
    #SIM_END_TIME;
    $display("========================================");
    $display("Simulation finished! Time: %0t ns", $time);
    $display("========================================");
    $finish;  // 结束仿真
end

endmodule