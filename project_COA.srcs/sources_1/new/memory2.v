module memory#(
    parameter INIT_MEM = 0,
    parameter INIT_FILE = "instr.mem"
)(
    input wire clk,
    input wire we_re,
    input wire request,
    input wire [7:0]address,
    input wire [31:0]data_in,
    input wire [3:0]mask,

    output wire [31:0]data_out
);

    reg [31:0] mem [0:255];
    integer i;

    // -----------------------------------------------------------------------
    // Hardcoded ILP-high benchmark (15 independent ALU ops + ecall)
    // $readmemh is simulation-only; FPGA BRAM needs explicit initial values.
    // To change program: replace the assignments below and re-synthesize.
    // -----------------------------------------------------------------------
    initial begin
        // Zero out all entries first
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'h00000013; // NOP (addi x0,x0,0)

            // ----------------------------------------------------
            // To run a benchmark, simply uncomment ONE of these
            // sections and comment out the others.
            // ----------------------------------------------------

            // === 1. SEQUENTIAL BENCHMARK ===
            /*
            mem[ 0] = 32'h00500093; // addi x1, x0, 5
            mem[ 1] = 32'h00108113; // addi x2, x1, 1
            mem[ 2] = 32'h00210193; // addi x3, x2, 2
            mem[ 3] = 32'h00318213; // addi x4, x3, 3
            mem[ 4] = 32'h00420293; // addi x5, x4, 4
            mem[ 5] = 32'h00528313; // addi x6, x5, 5
            mem[ 6] = 32'h00630393; // addi x7, x6, 6
            mem[ 7] = 32'h00738413; // addi x8, x7, 7
            mem[ 8] = 32'h00840493; // addi x9, x8, 8
            mem[ 9] = 32'h00948513; // addi x10, x9, 9
            mem[10] = 32'h00A50593; // addi x11, x10, 10
            mem[11] = 32'h00B58613; // addi x12, x11, 11
            mem[12] = 32'h00C60693; // addi x13, x12, 12
            mem[13] = 32'h00D68713; // addi x14, x13, 13
            mem[14] = 32'h00E70793; // addi x15, x14, 14
            mem[15] = 32'h00000073; // ebreak
            */

            // === 2. MIXED-ILP BENCHMARK ===
            /*
            mem[ 0] = 32'h00500093; // addi x1, x0, 5
            mem[ 1] = 32'h00A00113; // addi x2, x0, 10
            mem[ 2] = 32'h00110193; // addi x3, x2, 1
            mem[ 3] = 32'h00208213; // addi x4, x1, 2
            mem[ 4] = 32'h01400293; // addi x5, x0, 20
            mem[ 5] = 32'h00528313; // addi x6, x5, 5
            mem[ 6] = 32'h00418393; // addi x7, x3, 4
            mem[ 7] = 32'h02800413; // addi x8, x0, 40
            mem[ 8] = 32'h00840493; // addi x9, x8, 8
            mem[ 9] = 32'h03200513; // addi x10,x0, 50
            mem[10] = 32'h00A50593; // addi x11,x10,10
            mem[11] = 32'h03C00613; // addi x12,x0, 60
            mem[12] = 32'h00C60693; // addi x13,x12,12
            mem[13] = 32'h04600713; // addi x14,x0, 70
            mem[14] = 32'h00E70793; // addi x15,x14,14
            mem[15] = 32'h00000073; // ebreak
            */

            // === 3. HIGH-ILP BENCHMARK ===
            mem[ 0] = 32'h00500093; // addi x1, x0, 5
            mem[ 1] = 32'h00A00113; // addi x2, x0, 10
            mem[ 2] = 32'h00F00193; // addi x3, x0, 15
            mem[ 3] = 32'h01400213; // addi x4, x0, 20
            mem[ 4] = 32'h01900293; // addi x5, x0, 25
            mem[ 5] = 32'h01E00313; // addi x6, x0, 30
            mem[ 6] = 32'h02300393; // addi x7, x0, 35
            mem[ 7] = 32'h02800413; // addi x8, x0, 40
            mem[ 8] = 32'h02D00493; // addi x9, x0, 45
            mem[ 9] = 32'h03200513; // addi x10, x0, 50
            mem[10] = 32'h03700593; // addi x11, x0, 55
            mem[11] = 32'h03C00613; // addi x12, x0, 60
            mem[12] = 32'h04100693; // addi x13, x0, 65
            mem[13] = 32'h04600713; // addi x14, x0, 70
            mem[14] = 32'h04B00793; // addi x15, x0, 75
            mem[15] = 32'h00000073; // ebreak

            // === 4. LOAD-HEAVY BENCHMARK ===
            /*
            mem[ 0] = 32'h00002083; // lw x1, 0(x0)      (Load from Memory addr 0)
            mem[ 1] = 32'h00108113; // addi x2, x1, 1    (Use x1 -> Load-Use Hazard! STALL)
            mem[ 2] = 32'h00002183; // lw x3, 0(x0)      (Load)
            mem[ 3] = 32'h00118213; // addi x4, x3, 1    (Use x3 -> STALL)
            mem[ 4] = 32'h00002283; // lw x5, 0(x0)      (Load)
            mem[ 5] = 32'h00128313; // addi x6, x5, 1    (Use x5 -> STALL)
            mem[ 6] = 32'h00002383; // lw x7, 0(x0)      (Load)
            mem[ 7] = 32'h00138413; // addi x8, x7, 1    (Use x7 -> STALL)
            mem[ 8] = 32'h00002483; // lw x9, 0(x0)      (Load)
            mem[ 9] = 32'h00148513; // addi x10, x9, 1   (Use x9 -> STALL)
            mem[10] = 32'h00002583; // lw x11, 0(x0)     (Load)
            mem[11] = 32'h00158613; // addi x12, x11, 1  (Use x11 -> STALL)
            mem[12] = 32'h00002683; // lw x13, 0(x0)     (Load)
            mem[13] = 32'h00168713; // addi x14, x13, 1  (Use x13 -> STALL)
            mem[14] = 32'h00000013; // nop               
            mem[15] = 32'h00000073; // ebreak
            */
            

    end

    always @(posedge clk) begin
        if (request && we_re) begin
            if(mask[0]) mem[address][7:0]   <= data_in[7:0];
            if(mask[1]) mem[address][15:8]  <= data_in[15:8];
            if(mask[2]) mem[address][23:16] <= data_in[23:16];
            if(mask[3]) mem[address][31:24] <= data_in[31:24];
        end
    end

    assign data_out = mem[address];
endmodule
