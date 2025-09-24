`timescale 1ns/1ps

module BLK_tb;

reg clk;
reg rst_n;
reg per_frame_vsync;
reg per_frame_hsync;
reg per_frame_href;
reg [7:0] per_img_red;
reg [7:0] per_img_green;
reg [7:0] per_img_blue;

wire post_frame_vsync;
wire post_frame_hsync;
wire post_frame_href;
wire [7:0] post_img_red;
wire [7:0] post_img_green;
wire [7:0] post_img_blue;

// 实例化待测模块
GaussianHighlightSuppressor #(
    .DATA_WIDTH(8),
    .THRESHOLD(200)
) uut (
    .clk(clk),
    .rst_n(rst_n),
    .per_frame_vsync(per_frame_vsync),
    .per_frame_hsync(per_frame_hsync),
    .per_frame_href(per_frame_href),
    .per_img_red(per_img_red),
    .per_img_green(per_img_green),
    .per_img_blue(per_img_blue),
    .post_frame_vsync(post_frame_vsync),
    .post_frame_hsync(post_frame_hsync),
    .post_frame_href(post_frame_href),
    .post_img_red(post_img_red),
    .post_img_green(post_img_green),
    .post_img_blue(post_img_blue)
);

// 时钟生成
initial clk = 0;
always #5.555 clk = ~clk; // 90MHz

// 激励过程
initial begin
    rst_n = 0;
    per_frame_vsync = 1;
    per_frame_hsync = 0;
    per_frame_href = 0;
    per_img_red = 0;
    per_img_green = 0;
    per_img_blue = 0;
    #20;
    rst_n = 1;

    // 模拟一帧数据
    repeat(2) begin // 两帧
        per_frame_vsync = 0;
        #10;
        per_frame_vsync = 1;
        repeat(10) begin // 五行
            per_frame_hsync = 1;
            #10;
            per_frame_hsync = 0;
            repeat(8) begin // 八个像素
                per_frame_href = 1;
                per_img_red = $random % 256;
                per_img_green = $random % 256;
                per_img_blue = $random % 256;
                #10;
                per_frame_href = 0;
                #10;
            end
        end
    end

    #100;
    $finish;
end

// 输出观察
initial begin
    $monitor("T=%0t | vsync=%b hsync=%b href=%b red=%h green=%h blue=%h | out_red=%h out_green=%h out_blue=%h",
        $time, per_frame_vsync, per_frame_hsync, per_frame_href, per_img_red, per_img_green, per_img_blue,
        post_img_red, post_img_green, post_img_blue);
end

endmodule