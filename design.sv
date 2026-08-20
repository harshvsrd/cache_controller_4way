// Code your design here
module cache_controller_4way (
    input  clk, rst,

    // CPU Port
    input  cpu_req, cpu_rw,      // 0: Read, 1: Write
    input  [31:0] cpu_addr, cpu_wdata,
    output reg cpu_ready,
    output reg  [31:0] cpu_rdata,

    // Main Memory Port
    output reg  mem_req, mem_rw, // 0: Read, 1: Write
    output reg [31:0] mem_addr,
    output reg [127:0] mem_wdata,
    input   mem_ready,
    input [127:0] mem_rdata
);

    localparam SETS = 256;
    wire [19:0] cpu_tag    = cpu_addr[31:12];
    wire [7:0]  cpu_index  = cpu_addr[11:4];
    wire [3:0]  cpu_offset = cpu_addr[3:0]; // 16 bytes per line

    // FSM States
    localparam IDLE       = 2'b00;
    localparam COMPARE    = 2'b01;
    localparam ALLOCATE   = 2'b10;
    localparam WRITE_BACK = 2'b11;
  
  
    reg valid_array [0:3][0:SETS-1];
    reg dirty_array [0:3][0:SETS-1];
    reg [19:0]  tag_array [0:3][0:SETS-1];
    reg [127:0] data_array  [0:3][0:SETS-1];
    
    // Round-Robin Pointer
    reg [1:0]rr_ptr[0:SETS-1]; 

    // State Flip-Flops
    reg [1:0] state, next_state;
    integer i;
  
  wire hit0=valid_array[0][cpu_index] && tag_array[0][cpu_index]==cpu_tag;
  wire hit1=valid_array[1][cpu_index] && tag_array[1][cpu_index]==cpu_tag;
  wire hit2=valid_array[2][cpu_index] && tag_array[2][cpu_index]==cpu_tag;
  wire hit3=valid_array[3][cpu_index] && tag_array[3][cpu_index]==cpu_tag;
  
  wire hit=hit0|hit1|hit2|hit3;
  wire [1:0] hit_way=hit0?0:hit1?1:hit2?2:3;
  wire [127:0] hit_block=data_array[hit_way][cpu_index];
  
  wire dirty=dirty_array[rr_ptr[cpu_index]][cpu_index];
  
  always@(*)
    begin
    case(cpu_offset[3:2])
      0:cpu_rdata=hit_block[31:0];
      1:cpu_rdata=hit_block[63:32];
      2:cpu_rdata=hit_block[95:64];
      3:cpu_rdata=hit_block[127:96];
  endcase
    end
  
  always@(posedge clk or posedge rst)
    begin
      if(rst) begin
        state=IDLE;
        for(i=0;i< SETS;i++) begin
          valid_array[0][i]<= 0;
          valid_array[1][i]<= 0;
          valid_array[2][i]<= 0;
          valid_array[3][i] <= 0;
           dirty_array[0][i] <= 0;
          dirty_array[1][i] <= 0;
            dirty_array[2][i] <= 0;
          dirty_array[3][i] <= 0;
                rr_ptr[i] <= 0;
        end
      end
        else begin
          state<=next_state;
          
      if (state == COMPARE&&hit &&cpu_rw == 1'b1) begin
                dirty_array[hit_way][cpu_index] <= 1'b1;
                case(cpu_offset[3:2])
                    0: data_array[hit_way][cpu_index][31:0] <=cpu_wdata;
                    1: data_array[hit_way][cpu_index][63:32]<= cpu_wdata;
                    2: data_array[hit_way][cpu_index][95:64]<= cpu_wdata;
                    3: data_array[hit_way][cpu_index][127:96]<=cpu_wdata;
                endcase
            end
            
            // Handle ALLOCATE 
            if (state == ALLOCATE && mem_ready) begin
                data_array[rr_ptr[cpu_index]][cpu_index] <= mem_rdata;
              tag_array[rr_ptr[cpu_index]][cpu_index]<=cpu_tag;
              valid_array[rr_ptr[cpu_index]][cpu_index]<=1;
              dirty_array[rr_ptr[cpu_index]][cpu_index]<=0;
              rr_ptr[cpu_index]<=rr_ptr[cpu_index]+1;
            end
           
        end
    end
    
  always@(*)
    begin
      next_state=state;
      mem_req=0;
      mem_rw=0;
      cpu_ready=0;
      mem_addr=0;
      mem_wdata=0;
      
      case(state)
        IDLE:if(cpu_req)
            next_state=COMPARE;
        COMPARE:begin
          if(hit)
          begin
            cpu_ready=1;
            next_state=IDLE;
          end
            else if(dirty)
              next_state=WRITE_BACK;
            else
              next_state=ALLOCATE;
        end
        
        
    WRITE_BACK:begin
        mem_req=1;
        mem_rw=1;
        mem_wdata=data_array[rr_ptr[cpu_index]][cpu_index];
        mem_addr= {tag_array[rr_ptr[cpu_index]][cpu_index], cpu_index, 4'b0000};
                
         if (mem_ready) next_state = ALLOCATE; 
        end
        
          ALLOCATE:begin
          mem_req=1;
          mem_rw=0;
          mem_addr= {tag_array[rr_ptr[cpu_index]][cpu_index], cpu_index, 4'b0000};
          
          if (mem_ready) next_state = COMPARE;
            end
        endcase
    end
endmodule
