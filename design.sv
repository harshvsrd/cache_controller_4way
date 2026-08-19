module cache_controller_4way (
    input  clk, rst,

    // CPU Port
    input  cpu_req, cpu_rw,      // 0: Read, 1: Write
    input  wire [31:0] cpu_addr, cpu_wdata,
    output reg         cpu_ready,
    output reg  [31:0] cpu_rdata,

    // Main Memory Port
    output reg         mem_req, mem_rw,      // 0: Read, 1: Write
    output reg  [31:0] mem_addr,
    output reg  [127:0] mem_wdata,
    input  wire        mem_ready,
    input  wire [127:0] mem_rdata
);

    // 1. Parameters & Address Decoding
    localparam SETS = 256;
    wire [19:0] cpu_tag    = cpu_addr[31:12];
    wire [7:0]  cpu_index  = cpu_addr[11:4];
    wire [3:0]  cpu_offset = cpu_addr[3:0]; // 16 bytes per line

    // FSM States
    localparam IDLE       = 2'b00;
    localparam COMPARE    = 2'b01;
    localparam ALLOCATE   = 2'b10;
    localparam WRITE_BACK = 2'b11;

    // 2. Cache Memory Arrays (4 Ways)
    reg         valid_array [0:3][0:SETS-1];
    reg         dirty_array [0:3][0:SETS-1];
    reg [19:0]  tag_array   [0:3][0:SETS-1];
    reg [127:0] data_array  [0:3][0:SETS-1];
    
    // Round-Robin Replacement Pointer (0 to 3) for each set
    reg [1:0]   rr_ptr      [0:SETS-1]; 

    reg [1:0] state, next_state;
    integer i;

    // 3. Datapath: Hit Detection Logic
    wire hit_0 = valid_array[0][cpu_index] & (tag_array[0][cpu_index] == cpu_tag);
    wire hit_1 = valid_array[1][cpu_index] & (tag_array[1][cpu_index] == cpu_tag);
    wire hit_2 = valid_array[2][cpu_index] & (tag_array[2][cpu_index] == cpu_tag);
    wire hit_3 = valid_array[3][cpu_index] & (tag_array[3][cpu_index] == cpu_tag);

    wire cache_hit = hit_0 | hit_1 | hit_2 | hit_3;

    wire [1:0] hit_way = hit_0 ? 2'd0 :
                         hit_1 ? 2'd1 :
                         hit_2 ? 2'd2 : 2'd3;

    wire [1:0] victim_way = rr_ptr[cpu_index];
    wire victim_dirty     = dirty_array[victim_way][cpu_index];

    wire [127:0] hit_data_block = data_array[hit_way][cpu_index];

    // 4. Sequential Logic: State Register ONLY
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // 5. Combinational Logic: FSM Next State & Outputs
    always @(*) begin
        next_state = state;
        cpu_ready  = 1'b0;
        mem_req    = 1'b0;
        mem_rw     = 1'b0;
        mem_addr   = 32'd0;
        mem_wdata  = 128'd0;
        cpu_rdata  = 32'd0;
        
        case(cpu_offset[3:2])
            2'b00: cpu_rdata = hit_data_block[31:0];
            2'b01: cpu_rdata = hit_data_block[63:32];
            2'b10: cpu_rdata = hit_data_block[95:64];
            2'b11: cpu_rdata = hit_data_block[127:96];
        endcase

        case (state)
            IDLE: begin
                if (cpu_req) next_state = COMPARE;
            end

            COMPARE: begin
                if (cache_hit) begin
                    cpu_ready  = 1'b1;
                    next_state = IDLE;
                end else begin
                    if (victim_dirty) begin
                        next_state = WRITE_BACK;
                    end else begin
                        next_state = ALLOCATE;
                    end
                end
            end

            ALLOCATE: begin
                mem_req  = 1'b1;
                mem_rw   = 1'b0; 
                mem_addr = {cpu_tag, cpu_index, 4'b0000}; 
                
                if (mem_ready) next_state = COMPARE; 
            end

            WRITE_BACK: begin
                mem_req   = 1'b1;
                mem_rw    = 1'b1; 
                mem_addr  = {tag_array[victim_way][cpu_index], cpu_index, 4'b0000};
                mem_wdata = data_array[victim_way][cpu_index];
                
                if (mem_ready) next_state = ALLOCATE; 
            end
        endcase
    end

    // 6. Sequential Logic: Memory Array Updates
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < SETS; i = i + 1) begin
                valid_array[0][i] <= 0; valid_array[1][i] <= 0;
                valid_array[2][i] <= 0; valid_array[3][i] <= 0;
                dirty_array[0][i] <= 0; dirty_array[1][i] <= 0;
                dirty_array[2][i] <= 0; dirty_array[3][i] <= 0;
                rr_ptr[i] <= 2'd0;
            end
        end else begin
            // Handle Write Hit
            if (state == COMPARE && cache_hit && cpu_rw == 1'b1) begin
                dirty_array[hit_way][cpu_index] <= 1'b1;
                case(cpu_offset[3:2])
                    2'b00: data_array[hit_way][cpu_index][31:0]   <= cpu_wdata;
                    2'b01: data_array[hit_way][cpu_index][63:32]  <= cpu_wdata;
                    2'b10: data_array[hit_way][cpu_index][95:64]  <= cpu_wdata;
                    2'b11: data_array[hit_way][cpu_index][127:96] <= cpu_wdata;
                endcase
            end
            
            // Handle ALLOCATE 
            if (state == ALLOCATE && mem_ready) begin
                data_array[victim_way][cpu_index]  <= mem_rdata;
                tag_array[victim_way][cpu_index]   <= cpu_tag;
                valid_array[victim_way][cpu_index] <= 1'b1;
                dirty_array[victim_way][cpu_index] <= 1'b0;
                rr_ptr[cpu_index] <= rr_ptr[cpu_index] + 1; 
            end
        end
    end

endmodule