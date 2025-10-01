`timescale 1ns/1ps

module pipe_MIPS32 (clk1, clk2);
    input clk1, clk2;   // Two-phase clock

    // -------------------------
    // IF/ID Pipeline Registers
    // -------------------------
    reg [31:0] PC, IF_ID_IR, IF_ID_NPC;

    // -------------------------
    // ID/EX Pipeline Registers
    // -------------------------
    reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;
    reg [ 2:0] ID_EX_type;

    // -------------------------
    // EX/MEM Pipeline Registers
    // -------------------------
    reg [31:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B;
    reg [ 2:0] EX_MEM_type;
    reg        EX_MEM_cond;

    // -------------------------
    // MEM/WB Pipeline Registers
    // -------------------------
    reg [31:0] MEM_WB_IR, MEM_WB_ALUOut, MEM_WB_LMD;
    reg [ 2:0] MEM_WB_type;

    // -------------------------
    // Register File & Memory
    // -------------------------
    reg [31:0] Reg_bank [0:31];        // Register bank (32 x 32)
    reg [31:0] Mem [0:1023];           // Memory (1024 x 32)

    // -------------------------
    // Opcodes
    // -------------------------
    parameter ADD   = 6'b000000,
              SUB   = 6'b000001,
              AND   = 6'b000010,
              OR    = 6'b000011,
              SLT   = 6'b000100,
              MUL   = 6'b000101,
              LW    = 6'b001000,
              SW    = 6'b001001,
              ADDI  = 6'b001010,
              SUBI  = 6'b001011,
              SLTI  = 6'b001100,
              BNEQZ = 6'b001101,
              BEQZ  = 6'b001110,
              HLT   = 6'b111111;

    // -------------------------
    // Instruction Types
    // -------------------------
    parameter RR_ALU = 3'b000,   // Register-Register ALU ops
              RM_ALU = 3'b001,   // Register-Immediate ALU ops
              LOAD   = 3'b010,
              STORE  = 3'b011,
              BRANCH = 3'b100,
              HALT   = 3'b101;

    // -------------------------
    // Control Flags
    // -------------------------
    reg HALTED;         // Set after HLT instruction (in WB stage)
    reg TAKEN_BRANCH;   // Disable following instructions after branch

// ===============================
// Instruction Fetch (IF) Stage
// ===============================
always @(posedge clk1) begin
    if (HALTED == 0) begin
        // ----- Branch handling -----
        if (((EX_MEM_IR[31:26] == BEQZ)  && (EX_MEM_cond == 1)) ||
            ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0))) begin

            IF_ID_IR     <= #2 Mem[EX_MEM_ALUOut];    // Fetch branch target instr
            IF_ID_NPC    <= #2 EX_MEM_ALUOut + 1;     // Next PC after branch
            PC           <= #2 EX_MEM_ALUOut + 1;     // Update PC
            TAKEN_BRANCH <= #2 1'b1;                  // Mark branch taken
        end
        
        // ----- Normal sequential fetch -----
        else begin
            IF_ID_IR     <= #2 Mem[PC];               // Fetch instr @ PC
            IF_ID_NPC    <= #2 PC + 1;                // Next PC
            PC           <= #2 PC + 1;                // Update PC
        end
    end
end


// ===============================
// Instruction Decode (ID) Stage
// ===============================
always @(posedge clk2) begin              
    if (HALTED == 0) begin
        // ----- Register Fetch -----
        if (IF_ID_IR[25:21] == 5'b00000)  
            ID_EX_A <= 32'b0;                      // rs = $zero
        else 
            ID_EX_A <= Reg_bank[IF_ID_IR[25:21]];       // rs value

        if (IF_ID_IR[20:16] == 5'b00000)  
            ID_EX_B <= 32'b0;                      // rt = $zero
        else 
            ID_EX_B <= Reg_bank[IF_ID_IR[20:16]];       // rt value

        // ----- Pass values to pipeline -----
        ID_EX_NPC <= IF_ID_NPC;                    // Next PC
        ID_EX_IR  <= IF_ID_IR;                     // Full instruction
        ID_EX_Imm <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]}; // Sign-extended imm

        // ----- Decode instruction type -----
        case (IF_ID_IR[31:26])
            ADD, SUB, AND, OR, SLT, MUL:   ID_EX_type <= RR_ALU;
            ADDI, SUBI, SLTI:              ID_EX_type <= RM_ALU;
            LW:                            ID_EX_type <= LOAD;
            SW:                            ID_EX_type <= STORE;
            BNEQZ, BEQZ:                   ID_EX_type <= BRANCH;
            HLT:                           ID_EX_type <= HALT;
            default:                       ID_EX_type <= HALT;   // Invalid opcode
        endcase
    end
end

// ===============================
// Execution (EX) Stage
// ===============================
always @(posedge clk1) begin
    if (HALTED == 0) begin
        EX_MEM_type   <= #2 ID_EX_type;
        EX_MEM_IR     <= #2 ID_EX_IR;
        TAKEN_BRANCH  <= #2 1'b0;

        case (ID_EX_type)

            // --------------------------------
            // Register-Register ALU Operations
            // --------------------------------
            RR_ALU: begin
                case (ID_EX_IR[31:26])   // opcode
                    ADD:    EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_B;
                    SUB:    EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_B;
                    AND:    EX_MEM_ALUOut <= #2 ID_EX_A & ID_EX_B;
                    OR:     EX_MEM_ALUOut <= #2 ID_EX_A | ID_EX_B;
                    SLT:    EX_MEM_ALUOut <= #2 (ID_EX_A < ID_EX_B);
                    MUL:    EX_MEM_ALUOut <= #2 ID_EX_A * ID_EX_B;
                    default:EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
                endcase
            end

            // --------------------------------
            // Register-Immediate ALU Operations
            // --------------------------------
            RM_ALU: begin
                case (ID_EX_IR[31:26])   // opcode
                    ADDI:   EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;
                    SUBI:   EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_Imm;
                    SLTI:   EX_MEM_ALUOut <= #2 (ID_EX_A < ID_EX_Imm);
                    default:EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
                endcase
            end

            // --------------------------------
            // Load / Store Instructions
            // --------------------------------
            LOAD, STORE: begin
                EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm; // Effective address
                EX_MEM_B      <= #2 ID_EX_B;             // Store data (if SW)
            end



            // --------------------------------
            // Branch Instructions
            // --------------------------------
            BRANCH: begin
                EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_Imm; // Branch target
                EX_MEM_cond   <= #2 (ID_EX_A == 0);        // Condition check
            end

        endcase
    end
end

// ===============================
// Memory (MEM) Stage
// ===============================
always @(posedge clk2) begin
    if (HALTED == 0) begin
        MEM_WB_type <= EX_MEM_type;
        MEM_WB_IR   <= #2 EX_MEM_IR;

        case (EX_MEM_type)

            // ----------------------------
            // ALU results (pass through)
            // ----------------------------
            RR_ALU, RM_ALU: begin
                MEM_WB_ALUOut <= #2 EX_MEM_ALUOut;
            end

            // ----------------------------
            // Load Instruction
            // ----------------------------
            LOAD: begin
                MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut];  // Load from memory
            end

            // ----------------------------
            // Store Instruction
            // ----------------------------
            STORE: begin
                if (TAKEN_BRANCH == 0)                // Disable write if branch
                    Mem[EX_MEM_ALUOut] <= #2 EX_MEM_B;
            end

        endcase
    end
end

// ===============================
// Write Back (WB) Stage
// ===============================
always @(posedge clk1) begin
    if (TAKEN_BRANCH == 0) begin   // Disable write if branch was taken
        case (MEM_WB_type)

            // ----------------------------
            // Register-Register ALU
            // Write result to "rd"
            // ----------------------------
            RR_ALU: begin
                Reg_bank[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUOut;
            end

            // ----------------------------
            // Register-Immediate ALU
            // Write result to "rt"
            // ----------------------------
            RM_ALU: begin
                Reg_bank[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOut;
            end

            // ----------------------------
            // Load Instruction
            // Write loaded data to "rt"
            // ----------------------------
            LOAD: begin
                Reg_bank[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD;
            end

            // ----------------------------
            // Halt Instruction
            // Stop execution
            // ----------------------------
            HALT: begin
                HALTED <= #2 1'b1;
            end

        endcase
    end
end

endmodule
