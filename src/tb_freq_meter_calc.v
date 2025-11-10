`timescale 1ns/1ns

module tb_freq_meter_calc();

//********************************************************************//
//****************** Parameter And Internal Signal *******************//
//********************************************************************//
//wire define
reg               sys_clk;
reg               sys_rst_n;
reg               clk_test;
wire      [7:0]   duty;
wire      [33:0]  freq;

//时钟、复位、待检测时钟的生成
initial begin
    sys_clk     = 1'b1;
    sys_rst_n   <= 1'b0;
    #200;
    sys_rst_n  <= 1'b1;
    #20;
    clk_test = 1'b1;
    #200;
end  // 修复：移除多余end语句[6](@ref)

//系统时钟生成（50MHz）
always #10 sys_clk = ~sys_clk;  // 周期20ns，频率50MHz

//待检测时钟生成（5MHz）[3](@ref)
always #100 clk_test = ~clk_test;  // 周期200ns，频率5MHz（修正延迟值）

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
// 修复：实例化实际设计模块而非自身以避免递归[2](@ref)
freq_meter_calc freq_meter_calc_inst (
    .sys_clk    (sys_clk),     //系统时钟,频率50MHz
    .sys_rst_n  (sys_rst_n),   //复位信号,低电平有效
    .clk_test   (clk_test),    //待检测时钟
    .duty       (duty),        //待检测时钟占空比
    .freq       (freq)         //待检测时钟频率
);

endmodule