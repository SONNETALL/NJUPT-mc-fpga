`timescale 1ns/1ns
module VIP_RAW8_RGB888_55
#(
    parameter   [13:0]  IMG_HDISP = 1280,   
    parameter   [13:0]  IMG_VDISP = 720
)
(
    //global clock
    input               clk,                
    input               rst_n,              
    
    input       [1:0]   mirror,

    //CMOS YCbCr444 data output
    input               per_frame_vsync,    
    input               per_frame_href,     
    input               per_frame_hsync, 
    input       [7:0]   per_img_RAW,        
    
    //CMOS RGB888 data output
    output              post_frame_vsync,   
    output              post_frame_href,    
    output              post_frame_hsync,   
    output reg  [7:0]   post_img_red,        
    output reg  [7:0]   post_img_green,    
    output reg  [7:0]   post_img_blue       
);

//----------------------------------------------------
//Generate 8Bit 3X3 Matrix for Video Image Processor.
    //Image data has been processd
wire                matrix_frame_vsync; //Prepared Image data vsync valid signal
wire                matrix_frame_href;  //Prepared Image data href vaild  signal
wire                matrix_frame_hsync; //Prepared Image data href vaild  signal
wire [10:0]   matrix_p11, matrix_p12, matrix_p13,matrix_p14,matrix_p15; //3X3 Matrix output
wire [10:0]   matrix_p21, matrix_p22, matrix_p23,matrix_p24,matrix_p25;
wire [10:0]   matrix_p31, matrix_p32, matrix_p33,matrix_p34,matrix_p35;
wire [10:0]   matrix_p41, matrix_p42, matrix_p43,matrix_p44,matrix_p45;
wire [10:0]   matrix_p51, matrix_p52, matrix_p53,matrix_p54,matrix_p55;
VIP_Matrix_Generate_5X5_8Bit    
#(
    .IMG_HDISP  (IMG_HDISP),    
    .IMG_VDISP  (IMG_VDISP)
)
u_VIP_Matrix_Generate_5X5_8Bit
(
    //global clock
    .clk                    (clk),                  //cmos video pixel clock
    .rst_n                  (rst_n),                //global reset

    //Image data prepred to be processd
    .per_frame_vsync        (per_frame_vsync),      //Prepared Image data vsync valid signal
    .per_frame_href         (per_frame_href),       //Prepared Image data href vaild  signal
    .per_frame_hsync        (per_frame_hsync),      //Prepared Image data href vaild  signal
    .per_img_Y              (per_img_RAW),          //Prepared Image brightness input

    //Image data has been processd
    .matrix_frame_vsync     (matrix_frame_vsync),   //Processed Image data vsync valid signal
    .matrix_frame_href      (matrix_frame_href),    //Processed Image data href vaild  signal
    .matrix_frame_hsync     (matrix_frame_hsync),   //Processed Image data href vaild  signal
    .matrix_p11(matrix_p11),    .matrix_p12(matrix_p12),    .matrix_p13(matrix_p13), .matrix_p14(matrix_p14),.matrix_p15(matrix_p15),   //3X3 Matrix output
    .matrix_p21(matrix_p21),    .matrix_p22(matrix_p22),    .matrix_p23(matrix_p23),.matrix_p24(matrix_p24),.matrix_p25(matrix_p25),
    .matrix_p31(matrix_p31),    .matrix_p32(matrix_p32),    .matrix_p33(matrix_p33),.matrix_p34(matrix_p34),.matrix_p35(matrix_p35),
    .matrix_p41(matrix_p41),    .matrix_p42(matrix_p42),    .matrix_p43(matrix_p43),.matrix_p44(matrix_p44),.matrix_p45(matrix_p45),
    .matrix_p51(matrix_p51),    .matrix_p52(matrix_p52),    .matrix_p53(matrix_p53),.matrix_p54(matrix_p54),.matrix_p55(matrix_p55)
);


//-------------------------------------------------------------
//sync the frame vsync and href signal and generate frame begin & end signal
reg     matrix_frame_href_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        matrix_frame_href_r <= 0;
    else
        matrix_frame_href_r <= matrix_frame_href;
end
wire    matrix_frame_href_end   =   (matrix_frame_href_r & ~matrix_frame_href) ? 1'b1 : 1'b0;   //Line over signal

//----------------------------------------
//Count the frame lines
reg [10:0]  line_cnt;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        line_cnt <= 0;
    else if(matrix_frame_vsync == 1'b1) //Frame valid
        begin
        if(matrix_frame_href_end)
            line_cnt <= (line_cnt < IMG_VDISP - 1'b1) ? line_cnt + 1'b1 : 11'd0;
        else
            line_cnt <= line_cnt;
        end
    else
        line_cnt <= 0;
end

//----------------------------------------
//Count the pixels
reg [13:0]  point_cnt;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        point_cnt <= 0;
    else if(matrix_frame_href == 1'b1)  //Line valid
        point_cnt <= (line_cnt < IMG_HDISP - 1'b1) ? point_cnt + 1'b1 : 11'd0;
    else
        point_cnt <= 0;
end

//--------------------------------------
//Convet RAW 2 RGB888 Format
//
localparam  OddLINE_OddPOINT    =   2'b11;  //odd lines + odd point
localparam  OddLINE_Even_POINT  =   2'b10;  //odd lines + even point
localparam  EvenLINE_OddPOINT   =   2'b01;  //even lines + odd point
localparam  EvenLINE_EvenPOINT  =   2'b00;  //even lines + even point
reg [10:0]   post_img_red_r;
reg [10:0]   post_img_green_r;
reg [10:0]   post_img_blue_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        post_img_red_r  <=  0;
        post_img_green_r<=  0;
        post_img_blue_r <=  0;
    end
    else
    begin
        case(mirror)
            2'b11 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                    //-------------------------GRGR...GRGR--------------------//
                    OddLINE_OddPOINT:   //odd lines + odd point
                    begin   //Center Red
                        post_img_red_r  <=  matrix_p33;
                        post_img_green_r<= ((matrix_p33<<2 )+ (matrix_p34<<1) +( matrix_p23<<1)+(matrix_p32<<1) +(matrix_p43<<1)-matrix_p13-matrix_p31-matrix_p53-matrix_p35)>>3;
                        post_img_blue_r <=  ((matrix_p33<<2)+ (matrix_p33<<1)+ (matrix_p22<<1) +(matrix_p44<<1)  +(matrix_p42<<1) +(matrix_p24<<1)-(matrix_p13+matrix_p31+matrix_p53+matrix_p35)-((matrix_p13+matrix_p31+matrix_p53+matrix_p35)>>1))>>3;
                    end//4
                    OddLINE_Even_POINT: //odd lines + even point
                    begin   //Center Green  
                    post_img_red_r  <=  ((matrix_p33<<2)+(matrix_p33) +( matrix_p23<<2)+( matrix_p43<<2)+ ((matrix_p31+ matrix_p35)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p13+ matrix_p53))>>3;
                        post_img_green_r<=  matrix_p33;
                        post_img_blue_r <=((matrix_p33<<2)+matrix_p33+ (matrix_p32<<2)+ (matrix_p34<<2)+ ((matrix_p13+ matrix_p53)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p31+ matrix_p35))>>3;
                    end//1
                    //-------------------------BGBG...BGBG--------------------//
                    EvenLINE_OddPOINT:  //even lines + odd point
                    begin   //Center Green
                        post_img_red_r  <=((matrix_p33<<2)+ matrix_p33+ (matrix_p32<<2)+ (matrix_p34<<2)+ ((matrix_p13+ matrix_p53)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p31+ matrix_p35))>>3;
                        post_img_green_r<=  matrix_p33;
                        post_img_blue_r <=  ((matrix_p33<<2)+ matrix_p33 +( matrix_p23<<2)+ (matrix_p43<<2)+ ((matrix_p31+ matrix_p35)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p13+ matrix_p53))>>3;
                    end//2
                    EvenLINE_EvenPOINT: //even lines + even point
                    begin   //Center Blue
                        post_img_red_r  <=  ((matrix_p33<<2)+ (matrix_p33<<1)+ (matrix_p22<<1) +( matrix_p44<<1) +( matrix_p42<<1)+(matrix_p24<<1)-(matrix_p13+matrix_p31+matrix_p53+matrix_p35)-((matrix_p13+matrix_p31+matrix_p53+matrix_p35)>>1))>>3;
                        post_img_green_r<= ((matrix_p33<<2) + (matrix_p34<<1) + (matrix_p23<<1)+(matrix_p32<<1) +(matrix_p43<<1)-matrix_p13-matrix_p31-matrix_p53-matrix_p35)>>3;
                        post_img_blue_r <=  matrix_p33;     
                    end//3
                endcase
            end
            2'b10 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                   //-------------------------GRGR...GRGR--------------------//
                   OddLINE_OddPOINT:   //odd lines + odd point
                   begin   //Center Green
                       post_img_red_r  <=((matrix_p33<<2)+ matrix_p33+ (matrix_p32<<2)+ (matrix_p34<<2)+ ((matrix_p13+ matrix_p53)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p31+ matrix_p35))>>3;
                        post_img_green_r<=  matrix_p33;
                        post_img_blue_r <=  ((matrix_p33<<2)+ matrix_p33 +( matrix_p23<<2)+ (matrix_p43<<2)+ ((matrix_p31+ matrix_p35)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p13+ matrix_p53))>>3;
                    end//2
                   OddLINE_Even_POINT: //odd lines + even point
                   begin   //Center Red
                        post_img_red_r  <=  matrix_p33;
                        post_img_green_r<= ((matrix_p33<<2 )+ (matrix_p34<<1) +( matrix_p23<<1)+(matrix_p32<<1) +(matrix_p43<<1)-matrix_p13-matrix_p31-matrix_p53-matrix_p35)>>3;
                        post_img_blue_r <=  ((matrix_p33<<2)+ (matrix_p33<<1)+ (matrix_p22<<1) +(matrix_p44<<1)  +(matrix_p42<<1) +(matrix_p24<<1)-(matrix_p13+matrix_p31+matrix_p53+matrix_p35)-((matrix_p13+matrix_p31+matrix_p53+matrix_p35)>>1))>>3;
                    end//4
                   //-------------------------BGBG...BGBG--------------------//
                   EvenLINE_OddPOINT:  //even lines + odd point
                    begin   //Center Blue
                       post_img_red_r  <=  ((matrix_p33<<2)+ (matrix_p33<<1)+ (matrix_p22<<1) +( matrix_p44<<1) +( matrix_p42<<1)+(matrix_p24<<1)-(matrix_p13+matrix_p31+matrix_p53+matrix_p35)-((matrix_p13+matrix_p31+matrix_p53+matrix_p35)>>1))>>3;
                        post_img_green_r<= ((matrix_p33<<2) + (matrix_p34<<1) + (matrix_p23<<1)+(matrix_p32<<1) +(matrix_p43<<1)-matrix_p13-matrix_p31-matrix_p53-matrix_p35)>>3;
                        post_img_blue_r <=  matrix_p33;
                    end//3
                   EvenLINE_EvenPOINT: //even lines + even point
                    begin   //Center Green  
                   post_img_red_r  <=  ((matrix_p33<<2)+(matrix_p33) +( matrix_p23<<2)+( matrix_p43<<2)+ ((matrix_p31+ matrix_p35)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p13+ matrix_p53))>>3;
                        post_img_green_r<=  matrix_p33;
                        post_img_blue_r <=((matrix_p33<<2)+matrix_p33+ (matrix_p32<<2)+ (matrix_p34<<2)+ ((matrix_p13+ matrix_p53)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p31+ matrix_p35))>>3;
                    end//1
                endcase
            end
            2'b00 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                    //-------------------------GBGB...GBGB--------------------//
                    OddLINE_OddPOINT:   //odd lines + odd point
                    begin   //Center Green   
                   post_img_red_r  <=  ((matrix_p33<<2)+(matrix_p33) +( matrix_p23<<2)+( matrix_p43<<2)+ ((matrix_p31+ matrix_p35)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p13+ matrix_p53))>>3;
                        post_img_green_r<=  matrix_p33;
                        post_img_blue_r <=((matrix_p33<<2)+matrix_p33+ (matrix_p32<<2)+ (matrix_p34<<2)+ ((matrix_p13+ matrix_p53)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p31+ matrix_p35))>>3;
                    end//1
                    OddLINE_Even_POINT: //odd lines + even point
                    begin   //Center Blue
                        post_img_red_r  <=  ((matrix_p33<<2)+ (matrix_p33<<1)+ (matrix_p22<<1) +( matrix_p44<<1) +( matrix_p42<<1)+(matrix_p24<<1)-(matrix_p13+matrix_p31+matrix_p53+matrix_p35)-((matrix_p13+matrix_p31+matrix_p53+matrix_p35)>>1))>>3;
                        post_img_green_r<= ((matrix_p33<<2) + (matrix_p34<<1) + (matrix_p23<<1)+(matrix_p32<<1) +(matrix_p43<<1)-matrix_p13-matrix_p31-matrix_p53-matrix_p35)>>3;
                        post_img_blue_r <=  matrix_p33;     
                    end//3
                    //-------------------------RGRG...RGRG--------------------//
                    EvenLINE_OddPOINT:  //even lines + odd point
                    begin   //Center Red
                         post_img_red_r  <=  matrix_p33;
                        post_img_green_r<= ((matrix_p33<<2 )+ (matrix_p34<<1) +( matrix_p23<<1)+(matrix_p32<<1) +(matrix_p43<<1)-matrix_p13-matrix_p31-matrix_p53-matrix_p35)>>3;
                        post_img_blue_r <=  ((matrix_p33<<2)+ (matrix_p33<<1)+ (matrix_p22<<1) +(matrix_p44<<1)  +(matrix_p42<<1) +(matrix_p24<<1)-(matrix_p13+matrix_p31+matrix_p53+matrix_p35)-((matrix_p13+matrix_p31+matrix_p53+matrix_p35)>>1))>>3;
                    end//4
                    EvenLINE_EvenPOINT: //even lines + even point
                     begin   //Center Green
                        post_img_red_r  <=((matrix_p33<<2)+ matrix_p33+ (matrix_p32<<2)+ (matrix_p34<<2)+ ((matrix_p13+ matrix_p53)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p31+ matrix_p35))>>3;
                        post_img_green_r<=  matrix_p33;
                        post_img_blue_r <=  ((matrix_p33<<2)+ matrix_p33 +( matrix_p23<<2)+ (matrix_p43<<2)+ ((matrix_p31+ matrix_p35)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p13+ matrix_p53))>>3;
                    end//2
                endcase
            end
            2'b01 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                    //-------------------------BGBG...BGBG--------------------//
                    OddLINE_OddPOINT:   //odd lines + odd point
                   begin   //Center Blue
                       post_img_red_r  <=  ((matrix_p33<<2)+ (matrix_p33<<1)+ (matrix_p22<<1) +( matrix_p44<<1) +( matrix_p42<<1)+(matrix_p24<<1)-(matrix_p13+matrix_p31+matrix_p53+matrix_p35)-((matrix_p13+matrix_p31+matrix_p53+matrix_p35)>>1))>>3;
                        post_img_green_r<= ((matrix_p33<<2) + (matrix_p34<<1) + (matrix_p23<<1)+(matrix_p32<<1) +(matrix_p43<<1)-matrix_p13-matrix_p31-matrix_p53-matrix_p35)>>3;
                        post_img_blue_r <=  matrix_p33;     
                    end//3
                    OddLINE_Even_POINT: //odd lines + even point
                    begin   //Center Green  
                    post_img_red_r  <=  ((matrix_p33<<2)+(matrix_p33) +( matrix_p23<<2)+( matrix_p43<<2)+ ((matrix_p31+ matrix_p35)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p13+ matrix_p53))>>3;
                        post_img_green_r<=  matrix_p33;
                        post_img_blue_r <=((matrix_p33<<2)+matrix_p33+ (matrix_p32<<2)+ (matrix_p34<<2)+ ((matrix_p13+ matrix_p53)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p31+ matrix_p35))>>3;
                    end//1
                    //-------------------------GRGR...GRGR--------------------//
                    EvenLINE_OddPOINT:  //even lines + odd point
                   begin   //Center Green
                        post_img_red_r  <=((matrix_p33<<2)+ matrix_p33+ (matrix_p32<<2)+ (matrix_p34<<2)+ ((matrix_p13+ matrix_p53)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p31+ matrix_p35))>>3;
                        post_img_green_r<=  matrix_p33;
                        post_img_blue_r <=  ((matrix_p33<<2)+ matrix_p33 +( matrix_p23<<2)+ (matrix_p43<<2)+ ((matrix_p31+ matrix_p35)>>1)-(matrix_p22+ matrix_p44+ matrix_p42+ matrix_p24+ matrix_p13+ matrix_p53))>>3;
                    end//2
                    EvenLINE_EvenPOINT: //even lines + even point
                    begin   //Center Red
                         post_img_red_r  <=  matrix_p33;
                        post_img_green_r<= ((matrix_p33<<2 )+ (matrix_p34<<1) +( matrix_p23<<1)+(matrix_p32<<1) +(matrix_p43<<1)-matrix_p13-matrix_p31-matrix_p53-matrix_p35)>>3;
                        post_img_blue_r <=  ((matrix_p33<<2)+ (matrix_p33<<1)+ (matrix_p22<<1) +(matrix_p44<<1)  +(matrix_p42<<1) +(matrix_p24<<1)-(matrix_p13+matrix_p31+matrix_p53+matrix_p35)-((matrix_p13+matrix_p31+matrix_p53+matrix_p35)>>1))>>3;
                    end//4
                endcase
            end
        endcase
    end
end

/*
localparam  OddLINE_OddPOINT    =   2'b11;  //odd lines + odd point
localparam  OddLINE_Even_POINT  =   2'b10;  //odd lines + even point
localparam  EvenLINE_OddPOINT   =   2'b01;  //even lines + odd point
localparam  EvenLINE_EvenPOINT  =   2'b00;  //even lines + even point
reg [9:0]   post_img_red_r;
reg [9:0]   post_img_green_r;
reg [9:0]   post_img_blue_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        post_img_red_r  <=  0;
        post_img_green_r<=  0;
        post_img_blue_r <=  0;
    end
    else
    begin
        case(mirror)
            2'b10 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                    //-------------------------GRGR...GRGR--------------------//
                    OddLINE_OddPOINT:   //odd lines + odd point
                    begin   //Center Red
                        post_img_red_r  <=  matrix_p22;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                    end
                    OddLINE_Even_POINT: //odd lines + even point
                    begin   //Center Green  
                        post_img_red_r  <=  (matrix_p21 + matrix_p23)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p12 + matrix_p32)>>1;
                    end
                    //-------------------------BGBG...BGBG--------------------//
                    EvenLINE_OddPOINT:  //even lines + odd point
                    begin   //Center Green
                        post_img_red_r  <=  (matrix_p12 + matrix_p32)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p21 + matrix_p23)>>1;
                    end
                    EvenLINE_EvenPOINT: //even lines + even point
                    begin   //Center Blue
                        post_img_red_r  <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  matrix_p22;     
                    end
                endcase
            end
            2'b11 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                   //-------------------------GRGR...GRGR--------------------//
                   OddLINE_OddPOINT:   //odd lines + odd point
                   begin   //Center Green  
                       post_img_red_r  <=  (matrix_p21 + matrix_p23)>>1;
                       post_img_green_r<=  matrix_p22;
                       post_img_blue_r <=  (matrix_p12 + matrix_p32)>>1;
                   end
                   OddLINE_Even_POINT: //odd lines + even point
                   begin   //Center Red
                       post_img_red_r  <=  matrix_p22;
                       post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                       post_img_blue_r <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                   end
                   //-------------------------BGBG...BGBG--------------------//
                   EvenLINE_OddPOINT:  //even lines + odd point
                   begin   //Center Blue
                       post_img_red_r  <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                       post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                       post_img_blue_r <=  matrix_p22;     
                   end
                   EvenLINE_EvenPOINT: //even lines + even point
                   begin   //Center Green
                       post_img_red_r  <=  (matrix_p12 + matrix_p32)>>1;
                       post_img_green_r<=  matrix_p22;
                       post_img_blue_r <=  (matrix_p21 + matrix_p23)>>1;
                   end
                endcase
            end
            2'b00 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                    //-------------------------GBGB...GBGB--------------------//
                    OddLINE_OddPOINT:   //odd lines + odd point
                    begin   //Center Green
                        post_img_red_r  <=  (matrix_p12 + matrix_p32)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p21 + matrix_p23)>>1;
                    end
                    OddLINE_Even_POINT: //odd lines + even point
                    begin   //Center Blue
                        post_img_red_r  <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  matrix_p22;
                    end
                    //-------------------------RGRG...RGRG--------------------//
                    EvenLINE_OddPOINT:  //even lines + odd point
                    begin   //Center Red
                        post_img_red_r  <=  matrix_p22;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                    end
                    EvenLINE_EvenPOINT: //even lines + even point
                    begin   //Center Green  
                        post_img_red_r  <=  (matrix_p21 + matrix_p23)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p12 + matrix_p32)>>1;
                    end
                endcase
            end
            2'b01 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                    //-------------------------BGBG...BGBG--------------------//
                    OddLINE_OddPOINT:   //odd lines + odd point
                    begin   //Center Blue
                        post_img_red_r  <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  matrix_p22;     
                    end
                    OddLINE_Even_POINT: //odd lines + even point
                    begin   //Center Green
                        post_img_red_r  <=  (matrix_p12 + matrix_p32)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p21 + matrix_p23)>>1;
                    end
                    //-------------------------GRGR...GRGR--------------------//
                    EvenLINE_OddPOINT:  //even lines + odd point
                    begin   //Center Green  
                        post_img_red_r  <=  (matrix_p21 + matrix_p23)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p12 + matrix_p32)>>1;
                    end
                    EvenLINE_EvenPOINT: //even lines + even point
                    begin   //Center Red
                        post_img_red_r  <=  matrix_p22;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                    end
                endcase
            end
        endcase
    end
end*/
// assign  post_img_red    =   post_img_red_r[7:0];
// assign  post_img_green  =   post_img_green_r[7:0];
// assign  post_img_blue   =   post_img_blue_r[7:0];

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        post_img_red <= 8'b0;
        post_img_green <= 8'b0;
        post_img_blue <= 8'b0;
    end
    else
    begin
        post_img_red <= post_img_red_r[7:0];
        post_img_green <= post_img_green_r[7:0];
        post_img_blue <= post_img_blue_r[7:0];
    end
end

//------------------------------------------
//lag n clocks signal sync      
reg [1:0]   post_frame_vsync_r;
reg [1:0]   post_frame_href_r;
reg [1:0]   post_frame_hsync_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
        post_frame_vsync_r  <=  0;
        post_frame_href_r   <=  0;
        post_frame_hsync_r  <=  0;
        end
    else
        begin
        post_frame_vsync_r  <=  {post_frame_vsync_r[0], matrix_frame_vsync};
        post_frame_href_r   <=  {post_frame_href_r[0],  matrix_frame_href};
        post_frame_hsync_r  <=  {post_frame_hsync_r[0], matrix_frame_hsync};
        end
end
assign  post_frame_vsync    =   post_frame_vsync_r[1];
assign  post_frame_href     =   post_frame_href_r[1];
assign  post_frame_hsync    =   post_frame_hsync_r[1];

endmodule
