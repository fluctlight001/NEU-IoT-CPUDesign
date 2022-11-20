# RV32_sram_func

## 文件结构

RV32

├── README.md #本文件

├── doc #参考文件   

├── mycpu #处理器代码(由于git不支持上传空文件夹，请自行创建)

├── riscv-test32 #测试用例

└── soc_sram_func #测试环境

## 使用说明

1. 请将自己的处理器代码置于 __mycpu__ 文件夹下。

2. 打开 __RV32\soc_sram_func\run_vivado\mycpu_prj1\mycpu.xpr__ 启动vivado。

3. 在vivado中添加 __mycpu__ 文件夹下的代码。

4. cpu顶层模块的模块名应为 __mycpu_top__ ,否则框架文件无法引用你的cpu。

5. 测试程序的起始地址为 __0x8010_0000__ ，请根据自己的处理器设计，自行修改pc的复位值。

6. 启动仿真并运行，下方控制台会提示当前进度和错误/通过的信息。

7. 如果报错提示 __mycpu__ 和 __reference__ 的结果不一致，请到 __riscv-test32__ 目录下找到 __*test_name*.txt__ 的汇编文件阅读理解程序内容找出错误。

8. 可能出现的错误类型

    |序号|错误形式|可能原因|
    |-|-|-|
    |1|提示中mycpu的pc比reference的pc大|reference所指示的那条指令没有正确写入寄存器|
    |2|提示中mycpu的pc比reference的pc小|mycpu所指示的那条指令本身不应该写入，或其写入值应与寄存器中原来的值相同|
    |3|提示中二者pc相同，但地址/数据不同|当前指令行为错误|
    |4|vivado编译报错|自行查询文档解决，搜索引擎是个好东西|

9. 通过修改 __RV32\soc_sram_func\testbench\mycpu_tb.v__ 中最下方的 __initial__ 模块，可以改变测试的内容。

10. 使用 __unit_test_all__ 测试并通过，即可认为测试完成。

11. 测试框架内包含虚拟串口的代码，如有项目展示需要，请自行阅读项目源码，理解工作原理后自行编写汇编程序驱动。

## mycpu_top接口说明

|序号|方向|位宽|信号名|备注|
|-|-|-|-|-|
|1|input|1|clk|时钟信号|
|2|input|1|rst_n|复位信号，低有效|
|3|input|6|ext_int|外部中断信号，需要设置该端口，内部逻辑可缺省，本次课设暂不做需求|
|4|input|1|inst_sram_en|指令ram 工作使能
|5|input|4|inst_sram_we|指令ram 字节写使能
|6|input|32|inst_sram_addr|指令ram 地址
|7|input|32|inst_sram_wdata|指令ram 写数据
|8|output|32|inst_sram_rdata|指令ram 读数据
|9|input|1|data_sram_en|数据ram 工作使能
|10|input|4|data_sram_we|数据ram 字节写使能
|11|input|32|data_sram_addr|数据ram 地址
|12|input|32|data_sram_wdata|数据ram 写数据
|13|output|32|data_sram_rdata|数据ram 读数据
|14|output|32|debug_wb_pc|wb阶段的指令的pc
|15|output|4|debug_wb_rf_we|wb阶段发给寄存器组的写使能
|16|output|5|debug_wb_rf_wnum|wb阶段发给寄存器组的写地址
|17|output|32|debug_wb_rf_wdata|wb阶段发给寄存器组的写数据

注：测试框架使用的存储器为时序存储器，在请求发出后的第一个时钟上升沿之后存储器才能完成请求。