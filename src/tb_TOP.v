`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Module: tb_TOP (Simple Version)
// Description: A minimal testbench for top_freq_meter
////////////////////////////////////////////////////////////////////////////////

module tb_TOP;

    // --- Testbench Signals ---
    reg clk;
    reg rst_n;
    reg clk_test;
    
    wire uart_tx;

    // --- Instantiate the Device Under Test (DUT) ---
    top_freq_meter uut (
        .clk(clk),
        .rst_n(rst_n),
        .clk_test(clk_test),
        .uart_tx(uart_tx)
    );

    // --- 1. 生成 50MHz 系统时钟 ---
    // 周期为 20ns (高电平10ns, 低电平10ns)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // --- 2. 生成激励信号 ---
    initial begin
        // 复位
        rst_n = 0;
        clk_test = 0;
        #200;  // 复位持续200ns
        rst_n = 1;
        #200;  // 复位后等待200ns

        // 生成一个 1kHz 的方波信号 (周期 = 1ms = 1,000,000ns)
        // 高电平 0.5ms (500,000ns), 低电平 0.5ms (500,000ns)
        forever begin
            #500000; // 等待 500,000 ns (0.5ms)
            clk_test = ~clk_test; // 翻转信号电平
        end
    end

    // --- 3. 监控和结束仿真 ---
    initial begin
        // 监控 uart_tx 信号，一旦有变化就会打印
        $monitor("Time=%0t ns | uart_tx=%b", $time, uart_tx);
        
        // 等待 1.5 秒后结束仿真 (1.5s = 1,500,000,000 ns)
        // 这个数值小于 2^31，可以避免溢出警告
        #1500000000; 
        $display("--- Simulation Finished ---");
        $finish;
    end

endmodule
