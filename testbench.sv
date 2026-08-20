`timescale 1ns/1ps

module tb_cache_controller;

    // 1. Signals
    reg clk, rst;
    
    // CPU Signals
    reg   cpu_req, cpu_rw;
    reg  [31:0] cpu_addr, cpu_wdata;
    wire  cpu_ready;
    wire [31:0] cpu_rdata;
    
    // Memory Signals
    wire   mem_req, mem_rw;
    wire [31:0]  mem_addr;
    wire [127:0] mem_wdata;
    reg    mem_ready;
    reg  [127:0] mem_rdata;

    // 2. Instantiate the DUT (Device Under Test)
    cache_controller_4way dut (
        .clk(clk),.rst(rst),
        .cpu_req(cpu_req),.cpu_rw(cpu_rw),.cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),.cpu_ready(cpu_ready),
        .cpu_rdata(cpu_rdata),
      .mem_req(mem_req),
        .mem_rw(mem_rw),
        .mem_addr(mem_addr),
           .mem_wdata(mem_wdata),
           .mem_ready(mem_ready),
        .mem_rdata(mem_rdata)
    );

    // 3. Clock Generation (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // 4. Dummy Main Memory Model (Cycle-Accurate)
    always @(posedge clk) begin
        if (rst) begin
            mem_ready <= 0;
            mem_rdata <= 0;
        end else begin
            if (mem_req && !mem_ready) begin
                // Simulate DRAM latency: Wait 3 clock cycles
                repeat(3) @(posedge clk);
                
                mem_ready <= 1;
                
                // If Read Request, send dummy 128-bit block
                if (!mem_rw) begin
                    // Sending 4 distinct 32-bit words so you can see the offset MUX working
                    mem_rdata <= {32'h44444444, 32'h33333333, 32'h22222222, 32'h11111111};
                end
            end else begin
                // Drop ready signal once transaction is complete
                mem_ready <= 0;
            end
        end
    end

    // 5. Stimulus (The CPU)
    initial begin
        // Required for EDA Playground Waveforms
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cache_controller);

        // Initialize CPU signals
        rst = 1;
        cpu_req = 0;
        cpu_rw = 0;
        cpu_addr = 0;
        cpu_wdata = 0;

        // Release Reset
        repeat(2) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);

        // TEST 1: Read Miss (Compulsory Miss)
        // Address: Tag=0x00010, Index=0x00, Offset=0x0
        $display("[%0t] TEST 1: CPU Read Miss", $time);
        @(posedge clk);
        cpu_req = 1;
        cpu_rw  = 0;
        cpu_addr = 32'h1000_0000;
        
        // Wait for handshake
        wait(cpu_ready == 1);
        @(posedge clk);
        $display("[%0t] TEST 1 COMPLETE: Cache returned data: %h", $time, cpu_rdata);
        cpu_req = 0; // Drop request
        repeat(2) @(posedge clk);

        // TEST 2: Read Hit 
        // Read exact same address, should hit instantly
        $display("[%0t] TEST 2: CPU Read Hit", $time);
        @(posedge clk);
        cpu_req = 1;
        cpu_rw  = 0;
        cpu_addr = 32'h1000_0000;
        
        wait(cpu_ready == 1);
        @(posedge clk);
        $display("[%0t] TEST 2 COMPLETE: Cache returned data: %h", $time, cpu_rdata);
        cpu_req = 0;
        repeat(2) @(posedge clk);
        // TEST 3: Write Hit
        // Write to offset 0x4 (2nd word of the line)
        $display("[%0t] TEST 3: CPU Write Hit", $time);
        @(posedge clk);
        cpu_req = 1;
        cpu_rw  = 1; // Write mode
        cpu_addr = 32'h1000_0004; // Offset is 4
        cpu_wdata = 32'hDEADBEEF;
        
        wait(cpu_ready == 1);
        @(posedge clk);
        $display("[%0t] TEST 3 COMPLETE: Wrote %h to cache", $time, cpu_wdata);
        cpu_req = 0;
        
        // End simulation
        repeat(5) @(posedge clk);
        $display("[%0t] Simulation Finished.", $time);
        $finish;
    end

endmodule