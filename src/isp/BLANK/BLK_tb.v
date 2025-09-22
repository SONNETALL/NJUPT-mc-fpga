`timescale 1ns/1ps

module BLK_tb;

reg clk;
reg rst_n;
reg vsync;
reg hsync;
reg de;
reg [7:0] data_in;

wire [7:0] data_out;
wire de_out;
wire vsync_out;
wire hsync_out;

// 实例化待测模块
BLK uut (
    .clk(clk),
    .rst_n(rst_n),
    .vsync(vsync),
    .hsync(hsync),
    .de(de),
    .data_in(data_in),
    .data_out(data_out),
    .de_out(de_out),
    .vsync_out(vsync_out),
    .hsync_out(hsync_out)
);

// 时钟生成
initial clk = 0;
always #5 clk = ~clk; // 100MHz

// 激励过程
initial begin
    rst_n = 0;
    vsync = 0;
    hsync = 0;
    de    = 0;
    data_in = 0;
    #20;
    rst_n = 1;

    // 模拟一帧数据
    repeat(2) begin // 两帧
        vsync = 1;
        #10;
        vsync = 0;
        repeat(5) begin // 五行
            hsync = 1;
            #10;
            hsync = 0;
            repeat(8) begin // 八个像素
                de = 1;
                data_in = $random % 256;
                #10;
                de = 0;
                #10;
            end
        end
    end

    #100;
    $finish;
end

// 输出观察
initial begin
    $monitor("T=%0t | vsync=%b hsync=%b de=%b data_in=%h | data_out=%h de_out=%b vsync_out=%b hsync_out=%b",
        $time, vsync, hsync, de, data_in, data_out, de_out, vsync_out, hsync_out);
end

endmodule