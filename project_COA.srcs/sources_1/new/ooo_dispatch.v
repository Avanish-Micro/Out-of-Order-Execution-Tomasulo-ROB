//============================================================================
// ooo_dispatch.v — Dispatch Stage for OOO RV32I Core
//
// Connects decode output to ROB + RAT + Reservation Stations.
// Stalls fetch if ROB or target RS is full.
//============================================================================
module ooo_dispatch (
    input wire        clk,
    input wire        rst,

    // --- Decoded instruction (from decode stage) ---
    input  wire        id_valid,          // instruction is valid in decode
    input  wire [31:0] id_pc,
    input  wire [4:0]  id_rs1_addr,
    input  wire [4:0]  id_rs2_addr,
    input  wire [4:0]  id_rd,
    input  wire [2:0]  id_funct3,
    input  wire [31:0] id_imm,
    input  wire [3:0]  id_alu_op,
    input  wire [1:0]  id_wb_sel,
    input  wire        id_reg_write,
    input  wire        id_mem_read,
    input  wire        id_mem_write,
    input  wire        id_use_pc,
    input  wire        id_use_imm,
    input  wire        id_branch,
    input  wire        id_jal,
    input  wire        id_jalr,
    input  wire        id_rs1_used,
    input  wire        id_rs2_used,
    input  wire        id_illegal,
    input  wire        id_ecall,
    input  wire        id_ebreak,

    // --- Register file read ports ---
    input  wire [31:0] rf_rs1_data,
    input  wire [31:0] rf_rs2_data,

    // --- RAT lookup results (combinational) ---
    input  wire        rat_rs1_valid,     // rs1 is renamed?
    input  wire [1:0]  rat_rs1_tag,
    input  wire        rat_rs2_valid,
    input  wire [1:0]  rat_rs2_tag,

    // --- ROB read interface (for renamed operands) ---
    output wire [1:0]  rob_read_tag_rs1,
    input  wire        rob_read_ready_rs1,
    input  wire [31:0] rob_read_value_rs1,
    output wire [1:0]  rob_read_tag_rs2,
    input  wire        rob_read_ready_rs2,
    input  wire [31:0] rob_read_value_rs2,

    // --- ROB allocate interface ---
    input  wire [1:0]  rob_alloc_tag,
    input  wire        rob_alloc_ready,   // ROB has free slot
    output wire        rob_alloc_req,

    // --- RAT rename interface ---
    output wire        rat_rename_en,
    output wire [4:0]  rat_rename_rd,
    output wire [1:0]  rat_rename_tag,

    // --- CDB Forwarding Interface ---
    input  wire        cdb_valid,
    input  wire [1:0]  cdb_tag,
    input  wire [31:0] cdb_value,

    // --- RS status ---
    input  wire        alu_rs_full,
    input  wire        load_rs_full,
    input  wire        store_rs_full,

    // --- Issue to ALU RS ---
    output reg         alu_rs_issue,
    output reg  [1:0]  alu_rs_rob_tag,
    output reg  [3:0]  alu_rs_alu_op,
    output reg         alu_rs_src1_ready,
    output reg  [1:0]  alu_rs_src1_tag,
    output reg  [31:0] alu_rs_src1_value,
    output reg         alu_rs_src2_ready,
    output reg  [1:0]  alu_rs_src2_tag,
    output reg  [31:0] alu_rs_src2_value,
    output reg  [31:0] alu_rs_imm,
    output reg  [31:0] alu_rs_pc,
    output reg         alu_rs_use_pc,
    output reg         alu_rs_use_imm,
    output reg  [2:0]  alu_rs_funct3,
    output reg         alu_rs_is_branch,
    output reg         alu_rs_jal,
    output reg         alu_rs_jalr,
    output reg  [1:0]  alu_rs_wb_sel,

    // --- Issue to Load RS ---
    output reg         load_rs_issue,
    output reg  [1:0]  load_rs_rob_tag,
    output reg  [3:0]  load_rs_alu_op,
    output reg         load_rs_src1_ready,
    output reg  [1:0]  load_rs_src1_tag,
    output reg  [31:0] load_rs_src1_value,
    output reg         load_rs_src2_ready,
    output reg  [1:0]  load_rs_src2_tag,
    output reg  [31:0] load_rs_src2_value,
    output reg  [31:0] load_rs_imm,
    output reg  [31:0] load_rs_pc,
    output reg  [2:0]  load_rs_funct3,
    output reg  [1:0]  load_rs_wb_sel,

    // --- Issue to Store RS ---
    output reg         store_rs_issue,
    output reg  [1:0]  store_rs_rob_tag,
    output reg  [3:0]  store_rs_alu_op,
    output reg         store_rs_src1_ready,
    output reg  [1:0]  store_rs_src1_tag,
    output reg  [31:0] store_rs_src1_value,
    output reg         store_rs_src2_ready,
    output reg  [1:0]  store_rs_src2_tag,
    output reg  [31:0] store_rs_src2_value,
    output reg  [31:0] store_rs_imm,
    output reg  [31:0] store_rs_pc,
    output reg  [2:0]  store_rs_funct3,

    // --- ROB allocate data ---
    output wire [4:0]  rob_alloc_rd,
    output wire [31:0] rob_alloc_pc,
    output wire        rob_alloc_is_store,
    output wire        rob_alloc_is_load,
    output wire        rob_alloc_is_branch,
    output wire [1:0]  rob_alloc_wb_sel,
    output wire        rob_alloc_reg_write,
    output wire [2:0]  rob_alloc_funct3,
    output wire        rob_alloc_ecall,
    output wire        rob_alloc_ebreak,
    output wire        rob_alloc_illegal,

    // --- Stall signal to fetch ---
    output wire        dispatch_stall
);

    // =====================================================================
    //  Determine target RS and stall conditions
    // =====================================================================
    wire is_alu_instr   = !id_mem_read && !id_mem_write;
    wire is_load_instr  = id_mem_read;
    wire is_store_instr = id_mem_write;

    wire target_rs_full = (is_alu_instr   && alu_rs_full)  ||
                          (is_load_instr  && load_rs_full) ||
                          (is_store_instr && store_rs_full);

    wire can_dispatch = id_valid && rob_alloc_ready && !target_rs_full;
    assign dispatch_stall = id_valid && (!rob_alloc_ready || target_rs_full);

    // =====================================================================
    //  ROB allocate signals
    // =====================================================================
    assign rob_alloc_req       = can_dispatch;
    assign rob_alloc_rd        = id_rd;
    assign rob_alloc_pc        = id_pc;
    assign rob_alloc_is_store  = is_store_instr;
    assign rob_alloc_is_load   = is_load_instr;
    assign rob_alloc_is_branch = id_branch || id_jal || id_jalr;
    assign rob_alloc_wb_sel    = id_wb_sel;
    assign rob_alloc_reg_write = id_reg_write;
    assign rob_alloc_funct3    = id_funct3;
    assign rob_alloc_ecall     = id_ecall;
    assign rob_alloc_ebreak    = id_ebreak;
    assign rob_alloc_illegal   = id_illegal;

    // =====================================================================
    //  RAT rename signals
    // =====================================================================
    assign rat_rename_en  = can_dispatch && id_reg_write && (id_rd != 5'd0);
    assign rat_rename_rd  = id_rd;
    assign rat_rename_tag = rob_alloc_tag;

    // =====================================================================
    //  ROB read for renamed operands
    // =====================================================================
    assign rob_read_tag_rs1 = rat_rs1_tag;
    assign rob_read_tag_rs2 = rat_rs2_tag;

    // =====================================================================
    //  Operand resolution (combinational)
    // =====================================================================
    reg        src1_ready;
    reg [1:0]  src1_tag;
    reg [31:0] src1_value;
    reg        src2_ready;
    reg [1:0]  src2_tag;
    reg [31:0] src2_value;

    always @(*) begin
        // Source 1
        if (!id_rs1_used || id_rs1_addr == 5'd0) begin
            src1_ready = 1'b1;
            src1_tag   = 2'd0;
            src1_value = 32'd0;
        end else if (rat_rs1_valid) begin
            // Renamed — check ROB for value
            if (rob_read_ready_rs1) begin
                src1_ready = 1'b1;
                src1_tag   = rat_rs1_tag;
                src1_value = rob_read_value_rs1;
            end else if (cdb_valid && cdb_tag == rat_rs1_tag) begin
                src1_ready = 1'b1;
                src1_tag   = rat_rs1_tag;
                src1_value = cdb_value;
            end else begin
                src1_ready = 1'b0;
                src1_tag   = rat_rs1_tag;
                src1_value = 32'd0;
            end
        end else begin
            src1_ready = 1'b1;
            src1_tag   = 2'd0;
            src1_value = rf_rs1_data;
        end

        // Source 2
        if (!id_rs2_used || id_rs2_addr == 5'd0) begin
            src2_ready = 1'b1;
            src2_tag   = 2'd0;
            src2_value = 32'd0;
        end else if (rat_rs2_valid) begin
            if (rob_read_ready_rs2) begin
                src2_ready = 1'b1;
                src2_tag   = rat_rs2_tag;
                src2_value = rob_read_value_rs2;
            end else if (cdb_valid && cdb_tag == rat_rs2_tag) begin
                src2_ready = 1'b1;
                src2_tag   = rat_rs2_tag;
                src2_value = cdb_value;
            end else begin
                src2_ready = 1'b0;
                src2_tag   = rat_rs2_tag;
                src2_value = 32'd0;
            end
        end else begin
            src2_ready = 1'b1;
            src2_tag   = 2'd0;
            src2_value = rf_rs2_data;
        end
    end

    // =====================================================================
    //  Issue to RS (combinational)
    // =====================================================================
    always @(*) begin
        // Default: no issue
        alu_rs_issue   = 1'b0;
        load_rs_issue  = 1'b0;
        store_rs_issue = 1'b0;

        // ALU RS defaults
        alu_rs_rob_tag    = rob_alloc_tag;
        alu_rs_alu_op     = id_alu_op;
        alu_rs_src1_ready = src1_ready;
        alu_rs_src1_tag   = src1_tag;
        alu_rs_src1_value = src1_value;
        alu_rs_src2_ready = src2_ready;
        alu_rs_src2_tag   = src2_tag;
        alu_rs_src2_value = src2_value;
        alu_rs_imm        = id_imm;
        alu_rs_pc         = id_pc;
        alu_rs_use_pc     = id_use_pc;
        alu_rs_use_imm    = id_use_imm;
        alu_rs_funct3     = id_funct3;
        alu_rs_is_branch  = id_branch;
        alu_rs_jal        = id_jal;
        alu_rs_jalr       = id_jalr;
        alu_rs_wb_sel     = id_wb_sel;

        // Load RS defaults
        load_rs_rob_tag    = rob_alloc_tag;
        load_rs_alu_op     = id_alu_op;
        load_rs_src1_ready = src1_ready;
        load_rs_src1_tag   = src1_tag;
        load_rs_src1_value = src1_value;
        load_rs_src2_ready = 1'b1;  // loads don't use rs2 for address
        load_rs_src2_tag   = 2'd0;
        load_rs_src2_value = 32'd0;
        load_rs_imm        = id_imm;
        load_rs_pc         = id_pc;
        load_rs_funct3     = id_funct3;
        load_rs_wb_sel     = id_wb_sel;

        // Store RS defaults
        store_rs_rob_tag    = rob_alloc_tag;
        store_rs_alu_op     = id_alu_op;
        store_rs_src1_ready = src1_ready;  // base address
        store_rs_src1_tag   = src1_tag;
        store_rs_src1_value = src1_value;
        store_rs_src2_ready = src2_ready;  // store data
        store_rs_src2_tag   = src2_tag;
        store_rs_src2_value = src2_value;
        store_rs_imm        = id_imm;
        store_rs_pc         = id_pc;
        store_rs_funct3     = id_funct3;

        if (can_dispatch) begin
            if (is_load_instr) begin
                load_rs_issue = 1'b1;
            end else if (is_store_instr) begin
                store_rs_issue = 1'b1;
            end else begin
                alu_rs_issue = 1'b1;
            end
        end
    end

endmodule
