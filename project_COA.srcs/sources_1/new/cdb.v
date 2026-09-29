//============================================================================
// cdb.v — Common Data Bus Arbiter
// Multiplexes results from ALU and Load units onto a single bus.
// Priority: ALU > Load (ALU is single-cycle, Load needs memory latency)
//============================================================================
module cdb (
    // --- ALU result input ---
    input  wire        alu_result_valid,
    input  wire [1:0]  alu_result_tag,
    input  wire [31:0] alu_result_value,
    input  wire        alu_branch_taken,
    input  wire [31:0] alu_branch_target,
    input  wire        alu_trap_valid,
    input  wire [31:0] alu_trap_cause,

    // --- Load result input ---
    input  wire        load_result_valid,
    input  wire [1:0]  load_result_tag,
    input  wire [31:0] load_result_value,

    // --- Store result input (address/data computation) ---
    input  wire        store_result_valid,
    input  wire [1:0]  store_result_tag,
    input  wire [31:0] store_result_addr,
    input  wire [31:0] store_result_data,
    input  wire [3:0]  store_result_mask,

    // --- CDB output ---
    output reg         cdb_valid,
    output reg  [1:0]  cdb_tag,
    output reg  [31:0] cdb_value,
    output reg         cdb_branch_taken,
    output reg  [31:0] cdb_branch_target,
    output reg         cdb_trap_valid,
    output reg  [31:0] cdb_trap_cause,
    output reg  [31:0] cdb_store_addr,
    output reg  [31:0] cdb_store_data,
    output reg  [3:0]  cdb_store_mask,

    // --- Stall signals (losing unit must retry next cycle) ---
    output wire        alu_stall,
    output wire        load_stall,
    output wire        store_stall
);

    // ALU > Store > Load priority
    assign alu_stall   = 1'b0;  // ALU always wins
    assign store_stall = alu_result_valid && store_result_valid;
    assign load_stall  = (alu_result_valid || store_result_valid) && load_result_valid;

    always @(*) begin
        cdb_valid         = 1'b0;
        cdb_tag           = 2'd0;
        cdb_value         = 32'd0;
        cdb_branch_taken  = 1'b0;
        cdb_branch_target = 32'd0;
        cdb_trap_valid    = 1'b0;
        cdb_trap_cause    = 32'd0;
        cdb_store_addr    = 32'd0;
        cdb_store_data    = 32'd0;
        cdb_store_mask    = 4'd0;

        if (alu_result_valid) begin
            cdb_valid         = 1'b1;
            cdb_tag           = alu_result_tag;
            cdb_value         = alu_result_value;
            cdb_branch_taken  = alu_branch_taken;
            cdb_branch_target = alu_branch_target;
            cdb_trap_valid    = alu_trap_valid;
            cdb_trap_cause    = alu_trap_cause;
        end else if (store_result_valid) begin
            cdb_valid         = 1'b1;
            cdb_tag           = store_result_tag;
            cdb_value         = 32'd0;  // stores don't produce register values
            cdb_store_addr    = store_result_addr;
            cdb_store_data    = store_result_data;
            cdb_store_mask    = store_result_mask;
        end else if (load_result_valid) begin
            cdb_valid         = 1'b1;
            cdb_tag           = load_result_tag;
            cdb_value         = load_result_value;
        end
    end
endmodule
