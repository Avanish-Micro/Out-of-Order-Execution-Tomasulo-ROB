//============================================================================
// rob.v — 4-entry Reorder Buffer for OOO RV32I Core
//
// Circular buffer: head = next to commit, tail = next to allocate.
// In-order allocate (from dispatch), in-order commit (from head).
// CDB writes mark entries ready.  Flush resets everything.
//============================================================================
module rob (
    input wire        clk,
    input wire        rst,

    // --- Allocate interface (from dispatch) ---
    input  wire        alloc_req,        // dispatch wants a new entry
    input  wire [4:0]  alloc_rd,         // destination register
    input  wire [31:0] alloc_pc,         // instruction PC
    input  wire        alloc_is_store,   // store instruction?
    input  wire        alloc_is_load,    // load instruction?
    input  wire        alloc_is_branch,  // branch instruction?
    input  wire [1:0]  alloc_wb_sel,     // writeback source select
    input  wire        alloc_reg_write,  // does this instr write a register?
    input  wire [2:0]  alloc_funct3,     // memory size / branch type
    input  wire        alloc_ecall,      // ecall flag
    input  wire        alloc_ebreak,     // ebreak flag
    input  wire        alloc_illegal,    // illegal instruction flag
    output wire [1:0]  alloc_tag,        // ROB index assigned
    output wire        alloc_ready,      // ROB has a free slot

    // --- CDB write interface ---
    input  wire        cdb_valid,
    input  wire [1:0]  cdb_tag,
    input  wire [31:0] cdb_value,
    input  wire        cdb_branch_taken,
    input  wire [31:0] cdb_branch_target,
    input  wire        cdb_trap_valid,
    input  wire [31:0] cdb_trap_cause,
    // Store-specific CDB fields
    input  wire [31:0] cdb_store_addr,
    input  wire [31:0] cdb_store_data,
    input  wire [3:0]  cdb_store_mask,

    // --- Commit interface (to register file / data memory) ---
    output wire        commit_valid,     // head is ready to commit
    output wire [4:0]  commit_rd,
    output wire [31:0] commit_value,
    output wire        commit_reg_write,
    output wire        commit_is_store,
    output wire [31:0] commit_store_addr,
    output wire [31:0] commit_store_data,
    output wire [3:0]  commit_store_mask,
    output wire [2:0]  commit_funct3,
    output wire        commit_is_branch,
    output wire        commit_branch_taken,
    output wire [31:0] commit_branch_target,
    output wire [31:0] commit_pc,
    output wire        commit_trap_valid,
    output wire [31:0] commit_trap_cause,
    output wire [1:0]  commit_tag,       // tag of committing entry (for RAT clear)
    input  wire        commit_ack,       // core acknowledges commit

    // --- Flush interface ---
    input  wire        flush,

    // --- Read interface (for dispatch operand lookup) ---
    input  wire [1:0]  read_tag,
    output wire        read_ready,       // entry has its result
    output wire [31:0] read_value,

    // --- Second read port (for rs2) ---
    input  wire [1:0]  read2_tag,
    output wire        read2_ready,
    output wire [31:0] read2_value,

    // --- Status ---
    output wire        rob_full,
    output wire        rob_empty
);

    // =====================================================================
    //  ROB entry storage
    // =====================================================================
    reg        valid     [0:3];
    reg        ready     [0:3];
    reg [4:0]  rd        [0:3];
    reg [31:0] value     [0:3];
    reg [31:0] pc        [0:3];
    reg        is_store  [0:3];
    reg        is_load   [0:3];
    reg        is_branch [0:3];
    reg        branch_taken  [0:3];
    reg [31:0] branch_target [0:3];
    reg [1:0]  wb_sel    [0:3];
    reg        reg_write [0:3];
    reg [2:0]  funct3    [0:3];
    reg        trap_valid[0:3];
    reg [31:0] trap_cause[0:3];
    reg [31:0] store_addr[0:3];
    reg [31:0] store_data_r[0:3];
    reg [3:0]  store_mask[0:3];

    // Head and tail pointers (2-bit for 4 entries)
    reg [1:0] head;
    reg [1:0] tail;
    reg [2:0] count;  // 0-4, needs 3 bits

    integer i;

    // =====================================================================
    //  Status outputs
    // =====================================================================
    assign rob_full  = (count == 3'd4);
    assign rob_empty = (count == 3'd0);
    assign alloc_tag   = tail;
    assign alloc_ready = !rob_full;

    // =====================================================================
    //  Commit outputs — always show head entry
    // =====================================================================
    assign commit_valid       = !rob_empty && valid[head] && ready[head];
    assign commit_rd          = rd[head];
    assign commit_value       = value[head];
    assign commit_reg_write   = reg_write[head];
    assign commit_is_store    = is_store[head];
    assign commit_store_addr  = store_addr[head];
    assign commit_store_data  = store_data_r[head];
    assign commit_store_mask  = store_mask[head];
    assign commit_funct3      = funct3[head];
    assign commit_is_branch   = is_branch[head];
    assign commit_branch_taken  = branch_taken[head];
    assign commit_branch_target = branch_target[head];
    assign commit_pc          = pc[head];
    assign commit_trap_valid  = trap_valid[head];
    assign commit_trap_cause  = trap_cause[head];
    assign commit_tag         = head;

    // =====================================================================
    //  Read interface (for dispatch operand lookup)
    // =====================================================================
    assign read_ready = valid[read_tag] && ready[read_tag];
    assign read_value = value[read_tag];

    // Second read port
    assign read2_ready = valid[read2_tag] && ready[read2_tag];
    assign read2_value = value[read2_tag];

    // =====================================================================
    //  Sequential logic
    // =====================================================================
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            head  <= 2'd0;
            tail  <= 2'd0;
            count <= 3'd0;
            for (i = 0; i < 4; i = i + 1) begin
                valid[i]     <= 1'b0;
                ready[i]     <= 1'b0;
                rd[i]        <= 5'd0;
                value[i]     <= 32'd0;
                pc[i]        <= 32'd0;
                is_store[i]  <= 1'b0;
                is_load[i]   <= 1'b0;
                is_branch[i] <= 1'b0;
                branch_taken[i]  <= 1'b0;
                branch_target[i] <= 32'd0;
                wb_sel[i]    <= 2'd0;
                reg_write[i] <= 1'b0;
                funct3[i]    <= 3'd0;
                trap_valid[i]<= 1'b0;
                trap_cause[i]<= 32'd0;
                store_addr[i]   <= 32'd0;
                store_data_r[i] <= 32'd0;
                store_mask[i]   <= 4'd0;
            end
        end else if (flush) begin
            head  <= 2'd0;
            tail  <= 2'd0;
            count <= 3'd0;
            for (i = 0; i < 4; i = i + 1) begin
                valid[i] <= 1'b0;
                ready[i] <= 1'b0;
            end
        end else begin
            // --- CDB write: mark entry ready with result ---
            if (cdb_valid) begin
                ready[cdb_tag]         <= 1'b1;
                value[cdb_tag]         <= cdb_value;
                branch_taken[cdb_tag]  <= cdb_branch_taken;
                branch_target[cdb_tag] <= cdb_branch_target;
                trap_valid[cdb_tag]    <= cdb_trap_valid;
                trap_cause[cdb_tag]    <= cdb_trap_cause;
                store_addr[cdb_tag]    <= cdb_store_addr;
                store_data_r[cdb_tag]  <= cdb_store_data;
                store_mask[cdb_tag]    <= cdb_store_mask;
            end

            // --- Allocate: dispatch writes a new entry at tail ---
            if (alloc_req && !rob_full) begin
                valid[tail]     <= 1'b1;
                ready[tail]     <= alloc_ecall || alloc_ebreak || alloc_illegal;  // traps are immediately ready
                rd[tail]        <= alloc_rd;
                value[tail]     <= 32'd0;
                pc[tail]        <= alloc_pc;
                is_store[tail]  <= alloc_is_store;
                is_load[tail]   <= alloc_is_load;
                is_branch[tail] <= alloc_is_branch;
                branch_taken[tail]  <= 1'b0;
                branch_target[tail] <= 32'd0;
                wb_sel[tail]    <= alloc_wb_sel;
                reg_write[tail] <= alloc_reg_write;
                funct3[tail]    <= alloc_funct3;
                trap_valid[tail]<= alloc_ecall || alloc_ebreak || alloc_illegal;
                trap_cause[tail]<= alloc_ecall  ? 32'd11 :
                                   alloc_ebreak ? 32'd3  :
                                   alloc_illegal? 32'd2  : 32'd0;
                store_addr[tail]   <= 32'd0;
                store_data_r[tail] <= 32'd0;
                store_mask[tail]   <= 4'd0;
            end

            // --- Pointer and count update ---
            // Both allocate and commit can happen in the same cycle
            if (alloc_req && !rob_full && commit_valid && commit_ack) begin
                // Allocate + commit simultaneously
                valid[head] <= 1'b0;
                ready[head] <= 1'b0;
                tail <= tail + 2'd1;
                head <= head + 2'd1;
                // count stays the same
            end else if (alloc_req && !rob_full) begin
                tail  <= tail + 2'd1;
                count <= count + 3'd1;
            end else if (commit_valid && commit_ack) begin
                valid[head] <= 1'b0;
                ready[head] <= 1'b0;
                head  <= head + 2'd1;
                count <= count - 3'd1;
            end
        end
    end

endmodule
