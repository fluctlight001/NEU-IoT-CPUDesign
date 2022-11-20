/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/
`timescale 1ns / 1ps

`define WORK_SPACE "../../../../../../../" // use your work_space 
`define TRACE_REF_FILE_PRFIX {`WORK_SPACE,"riscv-test32/"}
`define TRACE_REF_FILE(TEST_NAME) {`TRACE_REF_FILE_PRFIX,TEST_NAME,"-riscv32-nemu.lans"}
`define SOURCE_FILE(TEST_NAME) {`TRACE_REF_FILE_PRFIX,TEST_NAME,"-riscv32-nemu.data"}
`define CONFREG_NUM_REG      soc_lite.confreg.num_data
`define CONFREG_OPEN_TRACE   1'b1
`define CONFREG_NUM_MONITOR  1'b0
`define CONFREG_UART_DISPLAY soc_lite.confreg.write_uart_valid
`define CONFREG_UART_DATA    soc_lite.confreg.write_uart_data
`define END_PC 32'hbfc00100

module tb_top( );
reg resetn;
reg clk;

//goio
wire [15:0] led;
wire [1 :0] led_rg0;
wire [1 :0] led_rg1;
wire [7 :0] num_csn;
wire [6 :0] num_a_g;
wire [7 :0] switch;
wire [3 :0] btn_key_col;
wire [3 :0] btn_key_row;
wire [1 :0] btn_step;
assign switch      = 8'hff;
assign btn_key_row = 4'd0;
assign btn_step    = 2'd3;

// initial
// begin
//     clk = 1'b0;
//     resetn = 1'b0;
//     #2000;
//     resetn = 1'b1;
// end
always #5 clk=~clk;
soc_lite_top #(.SIMULATION(1'b1)) soc_lite
(
       .resetn      (resetn     ), 
       .clk         (clk        ),
    
        //------gpio-------
        .num_csn    (num_csn    ),
        .num_a_g    (num_a_g    ),
        .led        (led        ),
        .led_rg0    (led_rg0    ),
        .led_rg1    (led_rg1    ),
        .switch     (switch     ),
        .btn_key_col(btn_key_col),
        .btn_key_row(btn_key_row),
        .btn_step   (btn_step   )
    );   

//soc lite signals
//"soc_clk" means clk in cpu
//"wb" means write-back stage in pipeline
//"rf" means regfiles in cpu
//"w" in "wen/wnum/wdata" means writing
wire soc_clk;
wire [31:0] debug_wb_pc;
wire [3 :0] debug_wb_rf_wen;
wire [4 :0] debug_wb_rf_wnum;
wire [31:0] debug_wb_rf_wdata;
assign soc_clk           = soc_lite.cpu_clk;
assign debug_wb_pc       = soc_lite.debug_wb_pc;
assign debug_wb_rf_wen   = soc_lite.debug_wb_rf_wen;
assign debug_wb_rf_wnum  = soc_lite.debug_wb_rf_wnum;
assign debug_wb_rf_wdata = soc_lite.debug_wb_rf_wdata;

//wdata[i*8+7 : i*8] is valid, only wehile wen[i] is valid
wire [31:0] debug_wb_rf_wdata_v;
assign debug_wb_rf_wdata_v[31:24] = debug_wb_rf_wdata[31:24] & {8{debug_wb_rf_wen[3]}};
assign debug_wb_rf_wdata_v[23:16] = debug_wb_rf_wdata[23:16] & {8{debug_wb_rf_wen[2]}};
assign debug_wb_rf_wdata_v[15: 8] = debug_wb_rf_wdata[15: 8] & {8{debug_wb_rf_wen[1]}};
assign debug_wb_rf_wdata_v[7 : 0] = debug_wb_rf_wdata[7 : 0] & {8{debug_wb_rf_wen[0]}};

//get reference result in falling edge
reg        trace_cmp_flag;
reg        debug_end;

reg [31:0] ref_wb_pc;
reg [4 :0] ref_wb_rf_wnum;
reg [31:0] ref_wb_rf_wdata_v;
reg [31:0] debug_rf [31:0];
reg [31:0] line;
reg [31:0] ref_line;
reg trash;

// open the trace file;
integer trace_ref;

always @(posedge soc_clk)
begin 
    #1;
    if (!resetn) begin
        line <= 32'b0;
    end
    if(|debug_wb_rf_wen && debug_wb_rf_wnum!=5'd0 && debug_rf[debug_wb_rf_wnum]!==debug_wb_rf_wdata_v && `CONFREG_OPEN_TRACE)
    begin
        trace_cmp_flag=1'b0;
        while (!trace_cmp_flag && !($feof(trace_ref)))
        begin
            $fscanf(trace_ref, "%h %h $%d %h", trace_cmp_flag,
                    ref_wb_pc, ref_wb_rf_wnum, ref_wb_rf_wdata_v);
            line <= line + 1'b1;
        end
    end
end

//compare result in rsing edge 
reg debug_wb_err;
always @(posedge soc_clk)
begin
    #2;
    if(!resetn)
    begin
        debug_wb_err <= 1'b0;
        debug_rf[0] <= 0;
        debug_rf[1] <= 0;
        debug_rf[2] <= 0;
        debug_rf[3] <= 0;
        debug_rf[4] <= 0;
        debug_rf[5] <= 0;
        debug_rf[6] <= 0;
        debug_rf[7] <= 0;
        debug_rf[8] <= 0;
        debug_rf[9] <= 0;
        debug_rf[10] <= 0;
        debug_rf[11] <= 0;
        debug_rf[12] <= 0;
        debug_rf[13] <= 0;
        debug_rf[14] <= 0;
        debug_rf[15] <= 0;
        debug_rf[16] <= 0;
        debug_rf[17] <= 0;
        debug_rf[18] <= 0;
        debug_rf[19] <= 0;
        debug_rf[20] <= 0;
        debug_rf[21] <= 0;
        debug_rf[22] <= 0;
        debug_rf[23] <= 0;
        debug_rf[24] <= 0;
        debug_rf[25] <= 0;
        debug_rf[26] <= 0;
        debug_rf[27] <= 0;
        debug_rf[28] <= 0;
        debug_rf[29] <= 0;
        debug_rf[30] <= 0;
        debug_rf[31] <= 0;
    end
    else if(|debug_wb_rf_wen && debug_wb_rf_wnum!=5'd0 && debug_rf[debug_wb_rf_wnum]!==debug_wb_rf_wdata_v && `CONFREG_OPEN_TRACE)
    begin
        if (  (debug_wb_pc!==ref_wb_pc) || (debug_wb_rf_wnum!==ref_wb_rf_wnum)
            ||(debug_wb_rf_wdata_v!==ref_wb_rf_wdata_v) )
        begin
            $display("--------------------------------------------------------------");
            $display("[%t] Error!!!",$time);
            $display("    reference: PC = 0x%8h, wb_rf_wnum = 0x%2h, wb_rf_wdata = 0x%8h",
                      ref_wb_pc, ref_wb_rf_wnum, ref_wb_rf_wdata_v);
            $display("    mycpu    : PC = 0x%8h, wb_rf_wnum = 0x%2h, wb_rf_wdata = 0x%8h",
                      debug_wb_pc, debug_wb_rf_wnum, debug_wb_rf_wdata_v);
            $display("--------------------------------------------------------------");
            debug_wb_err <= 1'b1;
            #40;
            $finish;
        end
        else begin
            debug_rf[debug_wb_rf_wnum] <= debug_wb_rf_wdata_v;
        end
    end
end

//monitor test
initial
begin
    $timeformat(-9,0," ns",10);
    while(!resetn) #5;
    $display("==============================================================");
    $display("Test begin!");

    #10000;
    while(`CONFREG_NUM_MONITOR)
    begin
        #10000;
        $display ("        [%t] Test is running, debug_wb_pc = 0x%8h",$time, debug_wb_pc);
    end
end

//模拟串口打印
wire uart_display;
wire [7:0] uart_data;
assign uart_display = `CONFREG_UART_DISPLAY;
assign uart_data    = `CONFREG_UART_DATA;

always @(posedge soc_clk)
begin
    if(uart_display)
    begin
        if(uart_data==8'hff)
        begin
            ;//$finish;
        end
        else
        begin
            $write("%c",uart_data);
        end
    end
end

task unit_test;
input [64*8-1:0] test_name;
begin
    trash = 1'b1;
    trace_ref = $fopen(`TRACE_REF_FILE(test_name), "r");
    $fscanf(trace_ref, "%d", ref_line);
    $readmemh(`SOURCE_FILE(test_name),soc_lite.inst_ram.mem);
    $readmemh(`SOURCE_FILE(test_name),soc_lite.data_ram.mem);
    $display("        [%t] START TEST : \t%0s",$time, test_name);

    clk = 1'b0;
    resetn = 1'b0;
    #2000;
    resetn = 1'b1;

    // #5000
    while(ref_line!==line) begin
        #10
        trash = ~trash;
    end
    // $display("%d,%d",ref_line,line);
    if (ref_line==line) begin
        $display("        [%t] TEST PASS  : \t%0s",$time, test_name);
        // $finish;
    end
end
endtask

task unit_test_all;
begin
    unit_test("add-longlong");
    unit_test("add");
    unit_test("bit");
    unit_test("bubble-sort");
    // unit_test("div");
    unit_test("dummy");
    // unit_test("fact");
    unit_test("fib");
    // unit_test("goldbach");
    // unit_test("hello-str");
    unit_test("if-else");
    // unit_test("leap-year");
    unit_test("load-store");
    // unit_test("matrix-mul");
    unit_test("max");
    unit_test("min3");
    unit_test("mov-c");
    unit_test("movsx");
    // unit_test("mul-longlong");
    unit_test("pascal");
    // unit_test("prime");
    unit_test("quick-sort");
    // unit_test("recursion");
    unit_test("select-sort");
    unit_test("shift");
    // unit_test("shuixianhua");
    unit_test("string");
    unit_test("sub-longlong");
    unit_test("sum");
    unit_test("switch");
    unit_test("to-lower-case");
    unit_test("unalign");
    // unit_test("wanshu");

end
endtask

initial begin
    // unit_test("div");
    unit_test_all;
    $display("==============================================================");
    $display("Test end!");
    $display("----PASS!!!");
    $finish;
end
endmodule
