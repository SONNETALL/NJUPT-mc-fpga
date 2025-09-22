

`timescale 1ns/1ns
module VIP_Matrix_Generate_5X5_8Bit
#(
    parameter   [13:0]  IMG_HDISP = 11'd1280,    //640*480
    parameter   [13:0]  IMG_VDISP = 11'd720
)
(
    //global clock
    input               clk,                //cmos video pixel clock
    input               rst_n,              //global reset

    //Image data prepred to be processd
    input               per_frame_vsync,    //Prepared Image data vsync valid signal
    input               per_frame_href,     //Prepared Image data href vaild  signal
    input               per_frame_hsync,    //Prepared Image data href vaild  signal
    input       [7:0]   per_img_Y,          //Prepared Image brightness input

    //Image data has been processd
    output              matrix_frame_vsync, //Prepared Image data vsync valid signal
    output              matrix_frame_href,  //Prepared Image data href vaild  signal
    output              matrix_frame_hsync, //Prepared Image data href vaild  signal

    output  reg [10:0]   matrix_p11, matrix_p12, matrix_p13,matrix_p14,matrix_p15, //3X3 Matrix output
    output  reg [10:0]   matrix_p21, matrix_p22, matrix_p23,matrix_p24,matrix_p25,
    output  reg [10:0]   matrix_p31, matrix_p32, matrix_p33,matrix_p34,matrix_p35,
    output  reg [10:0]   matrix_p41, matrix_p42, matrix_p43,matrix_p44,matrix_p45,
    output  reg [10:0]   matrix_p51, matrix_p52, matrix_p53,matrix_p54,matrix_p55
    
);


// 一、生成5行图像数据（行缓存：通过Line_Shift_RAM级联实现）
// 定义5行数据：row5=当前输入行，row4=前1行，row3=前2行，row2=前3行，row1=前4行
wire    [7:0]   row1_data;  // 第1行（最早的行，前4行）
wire    [7:0]   row2_data;  // 第2行（前3行）
wire    [7:0]   row3_data;  // 第3行（前2行）
wire    [7:0]   row4_data;  // 第4行（前1行）
reg     [7:0]   row5_data;  // 第5行（当前输入行，直接锁存原始数据）

// 1. 锁存当前行数据（row5）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        row5_data <= 8'd0;
    else if (per_frame_href)  // 行有效时更新当前行，无效时保持
        row5_data <= per_img_Y;
    else
        row5_data <= row5_data;
end

// 2. 行移位RAM配置（每个RAM延迟1行，级联4个RAM得到前4行数据）
wire    shift_clk_en = per_frame_href;  // RAM使能：仅行有效时存储数据

// 第1个RAM：输入=当前行(row5)，输出=前1行(row4)
Line_Shift_RAM_8Bit
#(
    .DATA_WIDTH (8          ),  // 数据位宽：8bit
    .ADDR_WIDTH (11         ),  // 地址位宽：11bit可覆盖2048点（满足1080p）
    .DATA_DEPTH (IMG_HDISP  ),  // RAM深度：等于横向分辨率（存储1行数据）
    .DELAY_NUM  (0          )   // 额外延迟：0（仅延迟1行）
)
u0_Line_Shift_RAM_8Bit  // 输出：row4（前1行）
(
    .clk    (clk            ),
    .rst_n  (rst_n          ),
    .clken  (shift_clk_en   ),
    .din    (row5_data      ),  // 输入：当前行(row5)
    .dout   (row4_data      )   // 输出：前1行(row4)
);

// 第2个RAM：输入=row4，输出=前2行(row3)
Line_Shift_RAM_8Bit
#(
    .DATA_WIDTH (8          ),
    .ADDR_WIDTH (11         ),
    .DATA_DEPTH (IMG_HDISP  ),
    .DELAY_NUM  (0          )
)
u1_Line_Shift_RAM_8Bit  // 输出：row3（前2行）
(
    .clk    (clk            ),
    .rst_n  (rst_n          ),
    .clken  (shift_clk_en   ),
    .din    (row4_data      ),  // 输入：前1行(row4)
    .dout   (row3_data      )   // 输出：前2行(row3)
);

// 第3个RAM：输入=row3，输出=前3行(row2)
Line_Shift_RAM_8Bit
#(
    .DATA_WIDTH (8          ),
    .ADDR_WIDTH (11         ),
    .DATA_DEPTH (IMG_HDISP  ),
    .DELAY_NUM  (0          )
)
u2_Line_Shift_RAM_8Bit  // 输出：row2（前3行）
(
    .clk    (clk            ),
    .rst_n  (rst_n          ),
    .clken  (shift_clk_en   ),
    .din    (row3_data      ),  // 输入：前2行(row3)
    .dout   (row2_data      )   // 输出：前3行(row2)
);

// 第4个RAM：输入=row2，输出=前4行(row1)
Line_Shift_RAM_8Bit
#(
    .DATA_WIDTH (8          ),
    .ADDR_WIDTH (11         ),
    .DATA_DEPTH (IMG_HDISP  ),
    .DELAY_NUM  (0          )
)
u3_Line_Shift_RAM_8Bit  // 输出：row1（前4行）
(
    .clk    (clk            ),
    .rst_n  (rst_n          ),
    .clken  (shift_clk_en   ),
    .din    (row2_data      ),  // 输入：前3行(row2)
    .dout   (row1_data      )   // 输出：前4行(row1)
);


//------------------------------------------
//lag 2 clocks signal sync  
reg [4:0]   per_frame_vsync_r;
reg [4:0]   per_frame_href_r;   
reg [4:0]   per_frame_hsync_r; 
reg [13:0] row_cnt;
reg     [13:0]  pixel_cnt;
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
        per_frame_vsync_r   <=  {per_frame_vsync_r[3:0],    per_frame_vsync};
        per_frame_href_r    <=  {per_frame_href_r[3:0],     per_frame_href};
	  per_frame_hsync_r   <=  {per_frame_hsync_r[3:0],    per_frame_hsync}; 
        end
end
//Give up the 1th and 2th row edge data caculate for simple process
//Give up the 1th and 2th point of 1 line for simple process
wire    read_frame_href     =   per_frame_href_r[0]|per_frame_href_r[1];    //RAM read href sync signal
assign  matrix_frame_vsync  =   per_frame_vsync_r[4];
assign matrix_frame_href = (row_cnt >= 14'd4) ? per_frame_href_r[4] : 1'b0;
assign  matrix_frame_hsync  =   per_frame_hsync_r[4]; 


always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        row_cnt <= 14'd0;
    else if (~per_frame_vsync_r[4]) // 帧同步时重置行数
        row_cnt <= 14'd0;
    else if (per_frame_href_r[4] && (pixel_cnt == IMG_HDISP - 1)) // 每完成1行，行数+1
        row_cnt <= row_cnt + 14'd1;
end
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
/******************************************************************************
                    ----------  Convert Matrix  ----------
                [ P31 -> P32 -> P33 -> ]    --->    [ P11 P12 P13 ] 
                [ P21 -> P22 -> P23 -> ]    --->    [ P21 P22 P23 ]
                [ P11 -> P12 -> P11 -> ]    --->    [ P31 P32 P33 ]
******************************************************************************/
//---------------------------------------------------------------------------
//---------------------------------------------------
/***********************************************
    (1) Read data from Shift_RAM
    (2) Caculate the Sobel
    (3) Steady data after Sobel generate
************************************************/
//wire  [23:0]  matrix_row1 = {matrix_p11, matrix_p12, matrix_p13}; //Just for test
//wire  [23:0]  matrix_row2 = {matrix_p21, matrix_p22, matrix_p23};
//wire  [23:0]  matrix_row3 = {matrix_p31, matrix_p32, matrix_p33};

reg     [7:0]   row1_data0, row1_data1, row2_data0, row2_data1, row3_data0, row3_data1,row4_data0,row5_data0,row5_data1,row4_data1,row1_data2,row2_data2,row3_data2,row4_data2,row5_data2,row1_data3,row2_data3,row3_data3,row4_data3,row5_data3;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
        pixel_cnt <= 0;
        row1_data0 <= 0; row1_data1 <= 0;row1_data2 <= 0; row1_data3 <= 0;
        row2_data0 <= 0; row2_data1 <= 0;row2_data2 <= 0; row2_data3 <= 0;
        row3_data0 <= 0; row3_data1 <= 0;row3_data2 <= 0; row3_data3 <= 0;
        row4_data0 <= 0; row4_data1 <= 0;row4_data2 <= 0; row4_data3 <= 0;
        row5_data0 <= 0; row5_data1 <= 0;row5_data2 <= 0; row5_data3 <= 0;
        {matrix_p11, matrix_p12, matrix_p13,matrix_p14,matrix_p15} <= 55'h0;
        {matrix_p21, matrix_p22, matrix_p23,matrix_p24,matrix_p25} <= 55'h0;
        {matrix_p31, matrix_p32, matrix_p33,matrix_p34,matrix_p35} <= 55'h0;
        {matrix_p41, matrix_p42, matrix_p43,matrix_p44,matrix_p45} <= 55'h0;
        {matrix_p51, matrix_p52, matrix_p53,matrix_p54,matrix_p55} <= 55'h0;
        end
    else if(read_frame_href)
        begin
        pixel_cnt <=  (pixel_cnt < IMG_HDISP) ? pixel_cnt + 1'b1 : 14'd0;   //Point Counter
        {row1_data3,row1_data2,row1_data1, row1_data0} <= {row1_data2,row1_data1, row1_data0, row1_data};
        {row2_data3,row2_data2,row2_data1, row2_data0} <= {row2_data2,row2_data1, row2_data0, row2_data};
        {row3_data3,row3_data2,row3_data1, row3_data0} <= {row3_data2,row3_data1, row3_data0, row3_data};
        {row4_data3,row4_data2,row4_data1, row4_data0} <= {row4_data2,row4_data1, row4_data0, row4_data};
        {row5_data3,row5_data2,row5_data1, row5_data0} <= {row5_data2,row5_data1, row5_data0, row5_data};
        if(pixel_cnt == 0)
            begin
           {matrix_p11, matrix_p12, matrix_p13,matrix_p14,matrix_p15} <= 55'h0;
        {matrix_p21, matrix_p22, matrix_p23,matrix_p24,matrix_p25} <= 55'h0;
        {matrix_p31, matrix_p32, matrix_p33,matrix_p34,matrix_p35} <= 55'h0;
        {matrix_p41, matrix_p42, matrix_p43,matrix_p44,matrix_p45} <= 55'h0;
        {matrix_p51, matrix_p52, matrix_p53,matrix_p54,matrix_p55} <= 55'h0;
            end
        else if(pixel_cnt == 1)         //First point
            begin   
        {matrix_p11, matrix_p12, matrix_p13,matrix_p14,matrix_p15}<={{3{1'b0}},row1_data1,{3{1'b0}},row1_data1,{3{1'b0}},row1_data1,{3{1'b0}}, row1_data0,{3{1'b0}}, row1_data};
        {matrix_p21, matrix_p22, matrix_p23,matrix_p24,matrix_p25} <= {{3{1'b0}},row2_data1,{3{1'b0}},row2_data1,{3{1'b0}},row2_data1, {3{1'b0}},row2_data0,{3{1'b0}}, row2_data};
        {matrix_p31, matrix_p32, matrix_p33,matrix_p34,matrix_p35} <= {{3{1'b0}},row3_data1,{3{1'b0}},row3_data1,{3{1'b0}},row3_data1,{3{1'b0}}, row3_data0, {3{1'b0}},row3_data};
        {matrix_p41, matrix_p42, matrix_p43,matrix_p44,matrix_p45} <= {{3{1'b0}},row4_data1,{3{1'b0}},row4_data1,{3{1'b0}},row4_data1,{3{1'b0}}, row4_data0,{3{1'b0}}, row4_data};
        {matrix_p51, matrix_p52, matrix_p53,matrix_p54,matrix_p55} <= {{3{1'b0}},row5_data1,{3{1'b0}},row5_data1,{3{1'b0}},row5_data1,{3{1'b0}}, row5_data0,{3{1'b0}}, row5_data};
            end
            else if(pixel_cnt == 2)         //First point
            begin   
            {matrix_p11, matrix_p12, matrix_p13,matrix_p14,matrix_p15}<={{3{1'b0}},row1_data2,{3{1'b0}},row1_data2,{3{1'b0}},row1_data1, {3{1'b0}},row1_data0, {3{1'b0}},row1_data};
        {matrix_p21, matrix_p22, matrix_p23,matrix_p24,matrix_p25} <= {{3{1'b0}},row2_data2,{3{1'b0}},row2_data2,{3{1'b0}},row2_data1,{3{1'b0}}, row2_data0,{3{1'b0}}, row2_data};
        {matrix_p31, matrix_p32, matrix_p33,matrix_p34,matrix_p35} <= {{3{1'b0}},row3_data2,{3{1'b0}},row3_data2,{3{1'b0}},row3_data1,{3{1'b0}}, row3_data0, {3{1'b0}},row3_data};
        {matrix_p41, matrix_p42, matrix_p43,matrix_p44,matrix_p45} <= {{3{1'b0}},row4_data2,{3{1'b0}},row4_data2,{3{1'b0}},row4_data1,{3{1'b0}}, row4_data0,{3{1'b0}}, row4_data};
        {matrix_p51, matrix_p52, matrix_p53,matrix_p54,matrix_p55} <= {{3{1'b0}},row5_data2,{3{1'b0}},row5_data2,{3{1'b0}},row5_data1, {3{1'b0}},row5_data0,{3{1'b0}}, row5_data};
            end
        else if(pixel_cnt == IMG_HDISP-1) //Last Point        
            begin       
           {matrix_p11, matrix_p12, matrix_p13,matrix_p14,matrix_p15}<={{3{1'b0}},row1_data3,{3{1'b0}},row1_data2,{3{1'b0}},row1_data1, {3{1'b0}},row1_data1,{3{1'b0}}, row1_data1};
             {matrix_p21, matrix_p22, matrix_p23,matrix_p24,matrix_p25} <= {{3{1'b0}},row2_data3,{3{1'b0}},row2_data2,{3{1'b0}},row2_data1,{3{1'b0}}, row2_data1, {3{1'b0}},row2_data1};
             {matrix_p31, matrix_p32, matrix_p33,matrix_p34,matrix_p35} <= {{3{1'b0}},row3_data3,{3{1'b0}},row3_data2,{3{1'b0}},row3_data1,{3{1'b0}}, row3_data1,{3{1'b0}}, row3_data1};
             {matrix_p41, matrix_p42, matrix_p43,matrix_p44,matrix_p45} <= {{3{1'b0}},row4_data3,{3{1'b0}},row4_data2,{3{1'b0}},row4_data1,{3{1'b0}}, row4_data1,{3{1'b0}}, row4_data1};
             {matrix_p51, matrix_p52, matrix_p53,matrix_p54,matrix_p55} <= {{3{1'b0}},row5_data3,{3{1'b0}},row5_data2,{3{1'b0}},row5_data1,{3{1'b0}}, row5_data1,{3{1'b0}}, row5_data1};
            end
             else if(pixel_cnt == IMG_HDISP-2) //Last Point        
            begin       
           {matrix_p11, matrix_p12, matrix_p13,matrix_p14,matrix_p15}<={{3{1'b0}},row1_data3,{3{1'b0}},row1_data2,{3{1'b0}},row1_data1, {3{1'b0}},row1_data0,{3{1'b0}}, row1_data0};
             {matrix_p21, matrix_p22, matrix_p23,matrix_p24,matrix_p25} <= {{3{1'b0}},row2_data3,{3{1'b0}},row2_data2,{3{1'b0}},row2_data1,{3{1'b0}}, row2_data0, {3{1'b0}},row2_data0};
             {matrix_p31, matrix_p32, matrix_p33,matrix_p34,matrix_p35} <= {{3{1'b0}},row3_data3,{3{1'b0}},row3_data2,{3{1'b0}},row3_data1,{3{1'b0}}, row3_data0,{3{1'b0}}, row3_data0};
             {matrix_p41, matrix_p42, matrix_p43,matrix_p44,matrix_p45} <= {{3{1'b0}},row4_data3,{3{1'b0}},row4_data2,{3{1'b0}},row4_data1,{3{1'b0}}, row4_data0,{3{1'b0}}, row4_data0};
             {matrix_p51, matrix_p52, matrix_p53,matrix_p54,matrix_p55} <= {{3{1'b0}},row5_data3,{3{1'b0}},row5_data2,{3{1'b0}},row5_data1,{3{1'b0}}, row5_data0,{3{1'b0}}, row5_data0};
            end
        else                            //2 ~ IMG_HDISP-1 Point
            begin

             {matrix_p11, matrix_p12, matrix_p13,matrix_p14,matrix_p15}<={{3{1'b0}},row1_data3,{3{1'b0}},row1_data2,{3{1'b0}},row1_data1, {3{1'b0}},row1_data0,{3{1'b0}}, row1_data};
             {matrix_p21, matrix_p22, matrix_p23,matrix_p24,matrix_p25} <= {{3{1'b0}},row2_data3,{3{1'b0}},row2_data2,{3{1'b0}},row2_data1, {3{1'b0}},row2_data0,{3{1'b0}}, row2_data};
             {matrix_p31, matrix_p32, matrix_p33,matrix_p34,matrix_p35} <= {{3{1'b0}},row3_data3,{3{1'b0}},row3_data2,{3{1'b0}},row3_data1,{3{1'b0}}, row3_data0,{3{1'b0}}, row3_data};
             {matrix_p41, matrix_p42, matrix_p43,matrix_p44,matrix_p45} <= {{3{1'b0}},row4_data3,{3{1'b0}},row4_data2,{3{1'b0}},row4_data1, {3{1'b0}},row4_data0,{3{1'b0}}, row4_data};
             {matrix_p51, matrix_p52, matrix_p53,matrix_p54,matrix_p55} <= {{3{1'b0}},row5_data3,{3{1'b0}},row5_data2,{3{1'b0}},row5_data1, {3{1'b0}},row5_data0, {3{1'b0}},row5_data};
            end
        end
    else
        begin
        pixel_cnt <= 0;
        {matrix_p11, matrix_p12, matrix_p13,matrix_p14,matrix_p15} <= 55'h0;
        {matrix_p21, matrix_p22, matrix_p23,matrix_p24,matrix_p25} <= 55'h0;
        {matrix_p31, matrix_p32, matrix_p33,matrix_p34,matrix_p35} <= 55'h0;
        {matrix_p41, matrix_p42, matrix_p43,matrix_p44,matrix_p45} <= 55'h0;
        {matrix_p51, matrix_p52, matrix_p53,matrix_p54,matrix_p55} <= 55'h0;
        end
end

endmodule
