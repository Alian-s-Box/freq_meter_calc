module uart_freq_sender
(
    input wire clk,              // 系统时钟
    input wire rst_n,            // 复位信号
    input wire send_en,          // 发送使能信号
    input wire [7:0] duty,       // 占空比数据
    input wire [33:0] freq,      // 频率数据
    input wire [63:0] high_time, // 高电平时间
    input wire [63:0] low_time,  // 低电平时间
    
    output reg uart_tx,          // UART发送数据线
    output reg tx_busy,          // 发送忙信号
    output reg [7:0] debug_state // 调试状态（可选）
);

// UART参数定义
parameter CLK_FREQ = 50_000_000;  // 系统时钟频率
parameter BAUD_RATE = 115200;      // 目标波特率
parameter DATA_BITS = 8;           // 数据位
parameter STOP_BITS = 1;           // 停止位
parameter PARITY = 0;              // 校验位：0-无校验，1-奇校验，2-偶校验

// 波特率分频系数计算
localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

// 状态定义
localparam [3:0]
    IDLE        = 4'd0,
    SEND_HEADER = 4'd1,
    SEND_DUTY   = 4'd2,
    SEND_FREQ   = 4'd3,
    SEND_HIGH   = 4'd4,
    SEND_LOW    = 4'd5,
    SEND_TAIL   = 4'd6,
    SEND_CRLF   = 4'd7;

// 内部信号定义
reg [3:0] state, next_state;
reg [15:0] baud_counter;
reg [3:0] bit_counter;
reg [7:0] tx_shift_reg;
reg [7:0] data_buffer [0:31];//定义了一个32地址深度，位宽8位的缓冲区（ROM）
reg [5:0] data_index;
reg [4:0] byte_counter;
reg tx_active;
wire baud_tick;

// 波特率生成
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_counter <= 0;
    end else begin
        if (baud_counter >= BAUD_DIV - 1) begin
            baud_counter <= 0;
        end else begin
            baud_counter <= baud_counter + 1;
        end
    end
end

assign baud_tick = (baud_counter == BAUD_DIV - 1);//BAUD_DIV ≈ 434,每434个系统时钟周期 = 1个波特率周期

// 数据打包函数
function [7:0] hex_to_ascii;
    input [3:0] hex;
    begin
        hex_to_ascii = (hex < 4'd10) ? (8'h30 + hex) : (8'h37 + hex);//上位机以字符形式显示的时候，正好是该数据  
 end
endfunction

// 数据打包到缓冲区
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_index <= 0;
    end else if (send_en && state == IDLE) begin
        // 包头
        data_buffer[0]  = 8'h0D; // 回车
        data_buffer[1]  = 8'h0A; // 换行
        data_buffer[2]  = "F";
        data_buffer[3]  = "r";
        data_buffer[4]  = "e";
        data_buffer[5]  = "q";
        data_buffer[6]  = ":";
        data_buffer[7]  = " ";
        
        // 频率数据（34位，分成9个字节显示）
        data_buffer[8]  = hex_to_ascii(freq[33:30]);
        data_buffer[9]  = hex_to_ascii(freq[29:26]);
        data_buffer[10] = hex_to_ascii(freq[25:22]);
        data_buffer[11] = hex_to_ascii(freq[21:18]);
        data_buffer[12] = hex_to_ascii(freq[17:14]);
        data_buffer[13] = hex_to_ascii(freq[13:10]);
        data_buffer[14] = hex_to_ascii(freq[9:6]);
        data_buffer[15] = hex_to_ascii(freq[5:2]);
        data_buffer[16] = hex_to_ascii(freq[1:0]);
        data_buffer[17] = "H";
        data_buffer[18] = "z";
        data_buffer[19] = " ";
        
        // 占空比
        data_buffer[20] = "D";
        data_buffer[21] = "u";
        data_buffer[22] = "t";
        data_buffer[23] = "y";
        data_buffer[24] = ":";
        data_buffer[25] = " ";
        data_buffer[26] = hex_to_ascii(duty[7:4]);
        data_buffer[27] = hex_to_ascii(duty[3:0]);
        data_buffer[28] = "%";
        
        data_index <= 29; // 数据总长度
    end
end

// 状态机：发送打包好的数据
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        tx_busy <= 0;
        uart_tx <= 1'b1;
        tx_active <= 0;
        bit_counter <= 0;
        byte_counter <= 0;
    end else begin
        case (state)
            IDLE: begin
                tx_busy <= 0;
                uart_tx <= 1'b1;
                tx_active <= 0;
                bit_counter <= 0;
                byte_counter <= 0;
                
                if (send_en) begin
                    state <= SEND_HEADER;
                    tx_busy <= 1;
                end
            end
            
            SEND_HEADER: begin
                if (byte_counter < data_index) begin
                    if (!tx_active) begin
                        // 开始发送一个字节
                        tx_shift_reg <= data_buffer[byte_counter];
                        uart_tx <= 1'b0; // 起始位
                        tx_active <= 1;
                        bit_counter <= 0;
                    end else if (baud_tick) begin
                        if (bit_counter < DATA_BITS) begin
                            // 发送数据位
                            uart_tx <= tx_shift_reg[bit_counter];
                            bit_counter <= bit_counter + 1;
                        end else if (bit_counter == DATA_BITS) begin
                            // 发送停止位
                            uart_tx <= 1'b1;
                            bit_counter <= bit_counter + 1;
                        end else begin
                            // 一个字节发送完成
                            tx_active <= 0;
                            byte_counter <= byte_counter + 1;
                            
                            if (byte_counter == data_index - 1) begin
                                state <= SEND_CRLF;
                                byte_counter <= 0;
                            end
                        end
                    end
                end
            end
            
            SEND_CRLF: begin
                if (!tx_active) begin
                    // 发送回车换行
                    tx_shift_reg <= 8'h0D; // 回车
                    uart_tx <= 1'b0;
                    tx_active <= 1;
                    bit_counter <= 0;
                end else if (baud_tick) begin
                    if (bit_counter < DATA_BITS) begin
                        uart_tx <= tx_shift_reg[bit_counter];
                        bit_counter <= bit_counter + 1;
                    end else if (bit_counter == DATA_BITS) begin
                        uart_tx <= 1'b1;
                        bit_counter <= bit_counter + 1;
                    end else begin
                        tx_active <= 0;
                        if (byte_counter == 0) begin
                            // 发送换行
                            tx_shift_reg <= 8'h0A;
                            byte_counter <= 1;
                            tx_active <= 1;
                            bit_counter <= 0;
                            uart_tx <= 1'b0;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end
            end
            
            default: state <= IDLE;
        endcase
        
        debug_state <= state; // 调试用
    end
end

endmodule