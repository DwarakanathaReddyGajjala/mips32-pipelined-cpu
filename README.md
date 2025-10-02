# mips32-pipelined-cpu

##  Pipelined MIPS32 Processor (Verilog HDL)

This project implements a pipelined processor for a subset of the **MIPS32 Instruction Set Architecture (ISA)** in Verilog HDL.  

The design follows the classic five-stage datapath:  
- **Instruction Fetch (IF)**  
- **Instruction Decode (ID)**  
- **Execution (EX)**  
- **Memory (MEM)**  
- **Write-Back (WB)**  

The processor supports arithmetic, logical, memory, and branch instructions.  
Additional programs such as factorial, GCD, and sorting can be tested by adding custom testbenches.  


Pipeline hazards are handled using **NOP insertion** and a **dual-clock strategy**.  

---

##  Files
1. `pipe_MIPS32.v` – Verilog design of the pipelined processor  
2. `test_mips32_ex1.v` – Testbench with example 1 (**Addition**)  
3. `test_mips32_ex2.v` – Testbench with example 2 (**Memory operation**)  
4. Additional testbenches can be added for other programs (e.g., factorial, GCD, sorting).  

---

##  How to Run

### Option 1: Locally with Icarus Verilog
1. Install **Icarus Verilog (iverilog)** and **GTKWave** (for waveform viewing).  
2. Compile and run with:  

```sh
# Example 1: Addition
iverilog -o mips32 pipe_MIPS32.v test_mips32_ex1.v
vvp mips32

# Example 2: Memory operation
iverilog -o mips32 pipe_MIPS32.v test_mips32_ex2.v
vvp mips32
```
Option 2: Online with EDA Playground
1.  Go to [EDA Playground](https://www.edaplayground.com/)  
2. Paste the code from pipe_MIPS32.v and your testbench (test_mips32_ex1.v or test_mips32_ex2.v).
3. Select Icarus Verilog (iverilog) as the simulator.
4. Run the simulation to see console output and waveforms.

