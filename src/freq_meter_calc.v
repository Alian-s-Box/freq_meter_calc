//等精度测量信号频率

module freq_meter_calc
(
    input wire sys_clk,//系统基准时钟
    input wire sys_rst_n,
    input wire clk_test,//待检测信号

    output reg [7:0] duty ,//待测信号占空比
    output reg [33:0] freq ,//待测信号的频率
    output reg [63:0] high_time,
    output reg [63:0] low_time
);

parameter CNT_GATE_S_MAX =28'd74_999_999; //cnt_gate_s最大值，也就是闸门信号下降沿
parameter CNT_RISE_MAX =28'd12_500_000; //软件闸门拉高计数值，也就是什么时候闸门信号开始变为高电平
parameter CLK_STAND_FREQ =28'd100_000_000;

wire clk_stand;         //精度更高的标准时钟，频率为CLK_STAND_FREQ
wire gate_a_fall_s;     //clk_test域的下降沿检测指示
wire gate_a_fall_t;     //clk_stand域的下降沿检测指示

reg [27:0] cnt_gate_s ; //产生闸门信号需要借助计数器
reg gate_s;             //产生的软件闸门信号，为待测信号周期整数倍
reg gate_a;             //打拍后的闸门信号
reg gate_a_stand;       //打拍后的gate_a，帮助判断下降沿
reg gate_a_test;        //打拍后的gate_a，帮助判断下降沿

reg [47:0] cnt_clk_stand;           //在闸门信号内标准时钟信号的时钟数
reg [47:0] cnt_clk_stand_reg;       //记录闸门信号结束时cnt_clk_stand的值
reg [47:0] cnt_clk_test;            //在闸门信号内待测信号的时钟数
reg [47:0] cnt_clk_test_reg;        //记录闸门信号结束时cnt_clk_test的值
reg [47:0] cnt_clk_test_high;       //待检测时钟周期占空比高计数器
reg [47:0] cnt_clk_test_low;        //待检测时钟周期占空比低计数器
reg [47:0] cnt_clk_test_high_reg;   //待检测时钟周期占空比高计数器
reg [47:0] cnt_clk_test_low_reg;    //待检测时钟周期占空比低计数器

reg calc_flag;                          //计算标志信号
reg [63:0] freq_reg;                    //存储频率计算结果
reg [7:0] duty_reg;                     //存储占空比计算结果
reg calc_flag_reg;                      //打拍后的计算标志信号

/***************************************生成闸门信号*****************************************************/

//cnt_gate_s一直累加，到达CNT_GATE_S_MAX时清零
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n==1'b0)
        cnt_gate_s<=28'd0;
    else if(cnt_gate_s==CNT_GATE_S_MAX)
        cnt_gate_s<=28'd0;
    else 
        cnt_gate_s<=cnt_gate_s+1'b1;

//生成软件闸门，为待测信号周期整数倍
//当cnt_gate_s值超过CNT_RISE_MAX时gate_s拉高，在CNT_GATE_S_MAX再拉低
always@(posedge sys_clk or negedge sys_rst_n)
   if(sys_rst_n==1'b0)
        gate_s<=1'b0;
    else if ((cnt_gate_s>=CNT_RISE_MAX)
                &&(cnt_gate_s<=(CNT_GATE_S_MAX-CNT_RISE_MAX)))
        gate_s<=1'b1;
    else
        gate_s<=1'b0;

//打拍
always@(posedge clk_test or negedge sys_rst_n)
    if(sys_rst_n==1'b0)
        gate_a<=1'b0;
    else
        gate_a<=gate_s;

/***************************************待测信号频率计数*****************************************************/

//当gate_a为高电平时cnt_clk_test进行计数,记录clk_test周期数
always@(posedge clk_test or negedge sys_rst_n)
    if(sys_rst_n==1'b0)
        cnt_clk_test<=48'd0;
    else if(gate_a==1'b0)
        cnt_clk_test<=48'd0;
    else if(gate_a==1'b1)
        cnt_clk_test<=cnt_clk_test+1'b1;

//打拍
always@(posedge clk_test or negedge sys_rst_n)
    if(sys_rst_n==1'b0) 
        gate_a_test<=1'b0;
    else
        gate_a_test<=gate_a;

//利用打拍产生的延迟了一周期的信号进行边沿检测
assign gate_a_fall_t=((gate_a_test==1'b1)&&(gate_a==1'b0))
                     ?1'b1:1'b0;

//cnt_clk_test是一个实时变化的计数器，在下降沿后会清0，必须在测量结束时保存用于后续计算
always@(posedge clk_test or negedge sys_rst_n)
    if(sys_rst_n==1'b0)
        cnt_clk_test_reg<=32'd0;
    else if(gate_a_fall_t==1'b1)
        cnt_clk_test_reg<=cnt_clk_test;

/***************************************标准时钟频率计数*****************************************************/

//当gate_a为高电平时cnt_clk_stand进行计数,记录clk_stand周期数
always@(posedge clk_stand or negedge sys_rst_n)
    if(sys_rst_n==1'b0)
        cnt_clk_stand<=48'd0;
    else if(gate_a==1'b0)
        cnt_clk_stand<=48'd0;
    else if(gate_a==1'b1)
        cnt_clk_stand<=cnt_clk_stand+1'b1;

//打拍
always@(posedge clk_stand or negedge sys_rst_n)
    if(sys_rst_n==1'b0) 
        gate_a_stand<=1'b0;
    else
        gate_a_stand<=gate_a;

//利用打拍产生的延迟了一周期的信号进行边沿检测
assign gate_a_fall_s=((gate_a_stand==1'b1)&&(gate_a==1'b0))
                     ?1'b1:1'b0;

//在闸门信号下降沿时将cnt_clk_stand的值储存
always@(posedge clk_stand or negedge sys_rst_n) begin

    if(sys_rst_n==1'b0) begin
        cnt_clk_stand_reg<=32'd0;
        cnt_clk_test_low_reg <= 48'd0 ;
        cnt_clk_test_high_reg <= 48'd0 ;
    end

    else if(gate_a_fall_s==1'b1) begin
        cnt_clk_stand_reg<=cnt_clk_stand;
        //这两句是将下文的占空比计数值在下降沿时储存在寄存器中
        cnt_clk_test_low_reg <= cnt_clk_test_low ;
        cnt_clk_test_high_reg <= cnt_clk_test_high;
    end

end


/****************************占空比计数********************************************************/
//对待测信号clk_test打拍
reg   clk_test_reg  ;

always@(posedge clk_stand or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        clk_test_reg    <=  1'b0;
    else    
        clk_test_reg    <=  clk_test;

//闸门信号为高电平时：若待测信号为高电平则cnt_clk_test_high累加，若待测信号为低电平则cnt_clk_test_low累加。
//计数器触发边沿是标准时钟，是为了保持维持计数精度
//占空比为两个计数器的值之比，因为闸门信号为待测信号周期的整数倍，所以计数器的值肯定是单个周期的待测信号的计数值的整数倍
always@(posedge clk_stand or negedge sys_rst_n) begin

    if(sys_rst_n==1'b0) begin
        cnt_clk_test_high <= 48'd0;
        cnt_clk_test_low <= 48'd0;
    end
    
    else if(calc_flag_reg == 1'b1) begin
        cnt_clk_test_high <= 48'd0;
        cnt_clk_test_low <= 48'd0;
    end

    else if(gate_a == 1'b0) begin
        cnt_clk_test_high <= cnt_clk_test_high;
        cnt_clk_test_low <= cnt_clk_test_low;
    end

    else if(gate_a == 1'b1) begin
        if(clk_test_reg == 1'b1)
        cnt_clk_test_high <= cnt_clk_test_high + 1'b1 ;
        else
        cnt_clk_test_low <= cnt_clk_test_low + 1'b1 ;
    end
    
    else begin
        cnt_clk_test_high <= cnt_clk_test_high;
        cnt_clk_test_low <= cnt_clk_test_low;
    end
end

/*********************对寄存器值处理为频率、占空比***********************************/

//当产生闸门信号的计数器加到 最大值-1 时，使能calc_flag
//要同时计算来自两个时钟域的信号，因此必须在第三个共同的、可控的时钟域（sys_clk）中进行同步和启动计算​​。
//同样是为了解决跨时钟域的问题

always@(posedge sys_clk or negedge sys_rst_n) begin
    
    if (sys_rst_n == 1'b0) begin
        calc_flag <= 1'b0 ;
    end

    else if (cnt_gate_s == (CNT_GATE_S_MAX - 1'b1)) 
        calc_flag <= 1'b1 ;
    
    else 
        calc_flag <= 1'b0 ;

end

//calc_flag使能时，频率与占空比计算开始
always@(posedge sys_clk or negedge sys_rst_n) begin

    if (sys_rst_n == 1'b0) begin
        freq_reg <= 64'd0 ;
        duty_reg <= 8'd0 ;
    end

    else if (calc_flag == 1'b1) begin
       freq_reg <= (CLK_STAND_FREQ * cnt_clk_test_reg / (cnt_clk_stand_reg));
       duty_reg <=  (cnt_clk_test_high_reg*100)/(cnt_clk_test_high_reg+cnt_clk_test_low_reg);
    end

end

/*********************************将计算值输出********************************************************************/

//打拍，计算标志进行输出
always@(posedge sys_clk or negedge sys_rst_n) begin

    if (sys_rst_n == 1'b0)
        calc_flag_reg <= 1'b0 ;
    
    else 
        calc_flag_reg <= calc_flag ;

end

//将存储在寄存器中的计算结果输出给端口
always@(posedge sys_clk or negedge sys_rst_n) begin

    if (sys_rst_n == 1'b0) begin
        freq <= 34'd0 ;
        duty <= 8'd0 ;
    end

    else if (calc_flag_reg == 1'b1) begin
        freq <= freq_reg[33:0] ;
        duty <= duty_reg ;
        //直接将原本代码测量出来的频率与占空比的值拿来用，算出高低电平的时间
        high_time <= (duty_reg * freq_reg) / 100;
        low_time <= (100 - duty_reg) * freq_reg / 100;
    end

end

/**********************clk_stand模块实例化******************************/
   Gowin_PLL u_PLL(
        .clkout0(clk_stand), //output clkout0
        .clkin(sys_clk), //input clkin
        .reset(sys_rst_n) //input reset
    );

endmodule
