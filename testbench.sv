`timescale 1ns / 1ps

module tb_cache_controller();

    // Signals
    reg clk;
    reg rst;

    // CPU Signals
    reg         cpu_req;
    reg         cpu_rw;
    reg  [31:0] cpu_addr;
    reg  [31:0] cpu_wdata;
    wire        cpu_ready;
    wire [31:0] cpu_rdata;

    // Memory Signals
    wire         mem_req;
    wire         mem_rw;
    wire [31:0]  mem_addr;
    wire [127:0] mem_wdata;
    reg          mem_ready;
    reg  [127:0] mem_rdata;

    // Instantiate DUT
    cache_controller_4way uut (
        .clk(clk), .rst(rst),
        .cpu_req(cpu_req), .cpu_rw(cpu_rw),
        .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata),
        .cpu_ready(cpu_ready), .cpu_rdata(cpu_rdata),
        .mem_req(mem_req), .mem_rw(mem_rw),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_ready(mem_ready), .mem_rdata(mem_rdata)
    );

    // Clock
    always #5 clk = ~clk;

    // Mock Main Memory
    always @(posedge clk) begin
        if (rst) begin
            mem_ready <= 1'b0;
            mem_rdata <= 128'd0;
        end else if (mem_req && !mem_ready) begin
            #20; // simulate delay
            mem_ready <= 1'b1;
            mem_rdata <= {32'hCAFEBABE, 32'hCAFEBABE, 32'hCAFEBABE, 32'hCAFEBABE};
        end else if (!mem_req) begin
            mem_ready <= 1'b0;
        end
    end

    // Test Sequence
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cache_controller);
        
        clk = 0; rst = 1;
        cpu_req = 0; cpu_rw = 0; cpu_addr = 0; cpu_wdata = 0;

        #20 rst = 0;
        #10;

        $display("--- TEST 1: CPU Write Miss ---");
        @(posedge clk);
        cpu_req   = 1;
        cpu_rw    = 1; 
        cpu_addr  = 32'h0000_1000;
        cpu_wdata = 32'hDEADBEEF;

        wait(cpu_ready == 1'b1);
        @(posedge clk);
        cpu_req = 0; 
        $display("Test 1 Complete. Wrote DEADBEEF to Cache.");
        #20;

        $display("--- TEST 2: CPU Read Hit ---");
        @(posedge clk);
        cpu_req  = 1;
        cpu_rw   = 0; 
        cpu_addr = 32'h0000_1000;

        wait(cpu_ready == 1'b1);
        $display("Test 2 Complete. Read Data: %h (Expected: DEADBEEF)", cpu_rdata);
        @(posedge clk);
        cpu_req = 0;
        #20;

        $display("--- TEST 3: CPU Read Miss ---");
        @(posedge clk);
        cpu_req  = 1;
        cpu_rw   = 0; 
        cpu_addr = 32'h0000_2000;

        wait(cpu_ready == 1'b1);
        $display("Test 3 Complete. Read Data: %h (Expected: CAFEBABE)", cpu_rdata);
        @(posedge clk);
        cpu_req = 0;
        #20;

        $display("--- ALL TESTS FINISHED ---");
        $finish;
    end
endmodule