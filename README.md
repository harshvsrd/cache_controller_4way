# cache_controller_4way


## 📌 Overview
This repository contains a fully synthesizable, cycle-accurate 4-way set-associative cache controller designed in Verilog. It bridges a CPU and main memory, optimizing data fetch latencies using an efficient routing datapath and a strict Valid/Ready handshake protocol. The design is heavily verified using a cycle-accurate SystemVerilog testbench simulating real-world DRAM latencies.

## 🚀 Architecture Highlights
* **Associativity:** 4-Way Set Associative
* **Cache Line Size:** 16 bytes (128 bits)
* **Word Size:** 32 bits
* **Sets:** 256
* **Addressing:** 32-bit CPU Address (20-bit Tag, 8-bit Index, 4-bit Offset)
* **Write Policy:** Write-Back with Dirty Bit tracking
* **Replacement Policy:** Round-Robin

## 🛠️ Datapath & Control Path Separation
The architecture strictly separates combinational routing from sequential memory elements to ensure high-speed synthesis and zero latch generation:
* **Datapath (Combinational):** Instant tag comparison across all 4 ways and concurrent MUX routing for zero-delay read hits.
* **Control Path (FSM):** Handles memory allocation and write-back cycles.
* **Sequential Arrays:** Fast broadcast-routing to D-Flip-Flop arrays using 1-bit Write Enable (WE) decoders to prevent datapath logic delays.

## ⚙️ FSM States
The controller uses a 4-state Finite State Machine:
1. **IDLE:** Waits for `cpu_req`.
2. **COMPARE:** Evaluates Tag and Valid bits. If a hit occurs, triggers `cpu_ready` instantly. If a miss occurs, evaluates the Dirty bit.
3. **ALLOCATE:** Stalls the CPU and asserts `mem_req`. Waits for `mem_ready` to fetch the 128-bit block from main memory into the target cache line.
4. **WRITE_BACK:** Evicts a modified (dirty) cache block to main memory before allocating new data.

## 💻 Simulation & Verification
The design is verified using **Icarus Verilog** and is structured to be strictly compatible with **Verilator**. 

### Testbench Features (`tb.sv`):
* Implements a cycle-accurate dummy DRAM model to simulate memory latency.
* Validates Read Miss (Compulsory Miss) memory fetch timing.
* Validates Read Hit zero-cycle data return.
* Validates Write Hit offset modifications.

### How to Run (EDA Playground)
1. Set the simulator to **Icarus Verilog 0.10.0** (or Verilator).
2. Load `design.v` and `testbench.sv`.
3. Select **Open EPWave after run**.
4. Run the simulation to view the FSM state transitions and handshake timing.

## 🧠 Concepts Applied
* RTL Design & Synthesis Constraints
* Valid/Ready Handshake Protocols
* Glitch prevention and Latch-free Combinational Logic
* VLSI critical path optimization (MUX vs. Data Broadcasting)
