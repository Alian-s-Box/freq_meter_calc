module top_freq_meter
(
    input wire clk,           // 系统时钟
    input wire rst_n,         // 复位信号
    input wire clk_test,      // 待测信号
    output wire uart_tx      // UART发送引脚
);

// 频率计信号
wire [7:0] duty;
wire [33:0] freq;
wire [63:0] high_time;
wire [63:0] low_time;

// UART发送控制信号
reg send_en;
reg [23:0] send_timer;
wire tx_busy;

// 实例化频率计
freq_meter_calc u_freq_meter
(
    .sys_clk(clk),
    .sys_rst_n(rst_n),
    .clk_test(clk_test),
    .duty(duty),
    .freq(freq),
    .high_time(high_time),
    .low_time(low_time)
);

// 实例化UART发送器
uart_freq_sender u_uart_sender
(
    .clk(clk),
    .rst_n(rst_n),
    .send_en(send_en),
    .duty(duty),
    .freq(freq),
    .high_time(high_time),
    .low_time(low_time),
    .uart_tx(uart_tx),
    .tx_busy(tx_busy)
);

// 定时发送控制（每秒发送一次）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        send_timer <= 0;
        send_en <= 0;
    end else begin
        send_en <= 0;
        
        if (send_timer < 24'd50_000_000) begin // 1秒周期（50MHz时钟）
            send_timer <= send_timer + 1;
        end else begin
            send_timer <= 0;
            if (!tx_busy) begin
                send_en <= 1; // 启动发送
            end
        end
    end
end


endmodule