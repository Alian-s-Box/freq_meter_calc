实现功能：频率测量计，测量输入的数字信号的频率以及占空比，通过uart串口通信发送给上位机

开发板：高云ACG525 FPGA开发板

软件：Gowin、Modelsim

具体模块：
freq_meter_calc：接收输入的数字信号，并进行测量与数字处理
uart_freq_sender：接收freq_meter_calc的处理结果，并通过uart串口发送给上位机

<img width="1761" height="978" alt="image" src="https://github.com/user-attachments/assets/527f94f6-f46e-483a-bbb7-53ca403ed7a4" />

