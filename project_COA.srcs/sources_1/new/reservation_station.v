//============================================================================
// reservation_station.v — Parameterized Reservation Station
// NUM_ENTRIES=2 for ALU, NUM_ENTRIES=1 for Load, NUM_ENTRIES=1 for Store
// Fixed: uses constant index width to avoid $clog2(1)=0 issue
//============================================================================
module reservation_station #(
    parameter NUM_ENTRIES = 2
)(
    input wire clk, input wire rst,
    input wire issue_valid, input wire [1:0] issue_rob_tag,
    input wire [3:0] issue_alu_op,
    input wire issue_src1_ready, input wire [1:0] issue_src1_tag,
    input wire [31:0] issue_src1_value,
    input wire issue_src2_ready, input wire [1:0] issue_src2_tag,
    input wire [31:0] issue_src2_value,
    input wire [31:0] issue_imm, input wire [31:0] issue_pc,
    input wire issue_use_pc, input wire issue_use_imm,
    input wire [2:0] issue_funct3, input wire issue_is_branch,
    input wire issue_jal, input wire issue_jalr,
    input wire [1:0] issue_wb_sel,
    input wire issue_mem_read, input wire issue_mem_write,
    input wire cdb_valid, input wire [1:0] cdb_tag, input wire [31:0] cdb_value,
    output reg dispatch_valid, output reg [1:0] dispatch_rob_tag,
    output reg [3:0] dispatch_alu_op,
    output reg [31:0] dispatch_src1_value, output reg [31:0] dispatch_src2_value,
    output reg [31:0] dispatch_imm, output reg [31:0] dispatch_pc,
    output reg dispatch_use_pc, output reg dispatch_use_imm,
    output reg [2:0] dispatch_funct3, output reg dispatch_is_branch,
    output reg dispatch_jal, output reg dispatch_jalr,
    output reg [1:0] dispatch_wb_sel,
    output reg dispatch_mem_read, output reg dispatch_mem_write,
    input wire dispatch_ack,
    output wire rs_full,
    input wire flush
);
    // Use fixed 1-bit index (enough for up to 2 entries)
    localparam IDX_W = 1;

    reg        entry_valid     [0:NUM_ENTRIES-1];
    reg [1:0]  entry_rob_tag   [0:NUM_ENTRIES-1];
    reg [3:0]  entry_alu_op    [0:NUM_ENTRIES-1];
    reg        entry_src1_ready[0:NUM_ENTRIES-1];
    reg [1:0]  entry_src1_tag  [0:NUM_ENTRIES-1];
    reg [31:0] entry_src1_value[0:NUM_ENTRIES-1];
    reg        entry_src2_ready[0:NUM_ENTRIES-1];
    reg [1:0]  entry_src2_tag  [0:NUM_ENTRIES-1];
    reg [31:0] entry_src2_value[0:NUM_ENTRIES-1];
    reg [31:0] entry_imm       [0:NUM_ENTRIES-1];
    reg [31:0] entry_pc        [0:NUM_ENTRIES-1];
    reg        entry_use_pc    [0:NUM_ENTRIES-1];
    reg        entry_use_imm   [0:NUM_ENTRIES-1];
    reg [2:0]  entry_funct3    [0:NUM_ENTRIES-1];
    reg        entry_is_branch [0:NUM_ENTRIES-1];
    reg        entry_jal       [0:NUM_ENTRIES-1];
    reg        entry_jalr      [0:NUM_ENTRIES-1];
    reg [1:0]  entry_wb_sel    [0:NUM_ENTRIES-1];
    reg        entry_mem_read  [0:NUM_ENTRIES-1];
    reg        entry_mem_write [0:NUM_ENTRIES-1];

    integer i;

    // ----------------------------------------------------------------
    // Combinational: CDB-forwarded operand VALUES (for dispatch data only)
    // NOTE: Readiness is determined ONLY from registered entry_src*_ready
    //       to break the combinatorial loop through the CDB path.
    //       CDB forwarding for values is safe (doesn't affect valid/ready).
    // ----------------------------------------------------------------
    reg [31:0] s1_val_eff [0:NUM_ENTRIES-1];
    reg [31:0] s2_val_eff [0:NUM_ENTRIES-1];

    // ----------------------------------------------------------------
    // Combinational: ready-entry selection
    // ----------------------------------------------------------------
    reg found_ready;
    reg [IDX_W-1:0] ready_idx;

    // ----------------------------------------------------------------
    // Combinational: free-slot selection and occupancy count
    // ----------------------------------------------------------------
    reg found_free;
    reg [IDX_W-1:0] free_idx;
    reg [1:0] valid_count;

    // Full signal driven purely from valid_count computed below
    assign rs_full = (valid_count >= NUM_ENTRIES[1:0]);

    // Registered copy of ready_idx — used in clocked block only
    reg [IDX_W-1:0] ready_idx_r;

    // ----------------------------------------------------------------
    // Block 1: CDB value forwarding (for operand data capture only)
    //          Does NOT affect dispatch_valid — no loop possible
    // ----------------------------------------------------------------
    always @(*) begin
        for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
            s1_val_eff[i] = (cdb_valid && !entry_src1_ready[i] && entry_src1_tag[i] == cdb_tag) ?
                cdb_value : entry_src1_value[i];
            s2_val_eff[i] = (cdb_valid && !entry_src2_ready[i] && entry_src2_tag[i] == cdb_tag) ?
                cdb_value : entry_src2_value[i];
        end
    end

    // ----------------------------------------------------------------
    // Block 2: Ready-entry selection → drives dispatch_* outputs
    //          Uses ONLY registered entry_src*_ready (no CDB forwarding)
    //          This breaks the CDB combinatorial loop entirely.
    // ----------------------------------------------------------------
    always @(*) begin
        found_ready = 1'b0;
        ready_idx   = {IDX_W{1'b0}};
        for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
            if (!found_ready && entry_valid[i] && entry_src1_ready[i] && entry_src2_ready[i]) begin
                found_ready = 1'b1;
                ready_idx   = i[IDX_W-1:0];
            end
        end

        dispatch_valid      = found_ready;
        dispatch_rob_tag    = found_ready ? entry_rob_tag[ready_idx]   : 2'd0;
        dispatch_alu_op     = found_ready ? entry_alu_op[ready_idx]    : 4'd0;
        dispatch_src1_value = found_ready ? s1_val_eff[ready_idx]      : 32'd0;
        dispatch_src2_value = found_ready ? s2_val_eff[ready_idx]      : 32'd0;
        dispatch_imm        = found_ready ? entry_imm[ready_idx]       : 32'd0;
        dispatch_pc         = found_ready ? entry_pc[ready_idx]        : 32'd0;
        dispatch_use_pc     = found_ready ? entry_use_pc[ready_idx]    : 1'b0;
        dispatch_use_imm    = found_ready ? entry_use_imm[ready_idx]   : 1'b0;
        dispatch_funct3     = found_ready ? entry_funct3[ready_idx]    : 3'd0;
        dispatch_is_branch  = found_ready ? entry_is_branch[ready_idx] : 1'b0;
        dispatch_jal        = found_ready ? entry_jal[ready_idx]       : 1'b0;
        dispatch_jalr       = found_ready ? entry_jalr[ready_idx]      : 1'b0;
        dispatch_wb_sel     = found_ready ? entry_wb_sel[ready_idx]    : 2'd0;
        dispatch_mem_read   = found_ready ? entry_mem_read[ready_idx]  : 1'b0;
        dispatch_mem_write  = found_ready ? entry_mem_write[ready_idx] : 1'b0;
    end

    // ----------------------------------------------------------------
    // Block 3: Free-slot search + valid count
    //          Completely independent of ready_idx / dispatch_*
    // ----------------------------------------------------------------
    always @(*) begin
        found_free  = 1'b0;
        free_idx    = {IDX_W{1'b0}};
        valid_count = 2'd0;
        for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
            if (entry_valid[i]) valid_count = valid_count + 2'd1;
            if (!found_free && !entry_valid[i]) begin
                found_free = 1'b1;
                free_idx   = i[IDX_W-1:0];
            end
        end
    end

    // ----------------------------------------------------------------
    // Register ready_idx each cycle so the clocked block never
    // reads a combinatorial signal (breaks the LUTLP-1 loop)
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst) begin
        if (!rst) ready_idx_r <= {IDX_W{1'b0}};
        else       ready_idx_r <= ready_idx;
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
                entry_valid[i]      <= 1'b0; entry_rob_tag[i]    <= 2'd0;
                entry_alu_op[i]     <= 4'd0;
                entry_src1_ready[i] <= 1'b0; entry_src1_tag[i]   <= 2'd0;
                entry_src1_value[i] <= 32'd0;
                entry_src2_ready[i] <= 1'b0; entry_src2_tag[i]   <= 2'd0;
                entry_src2_value[i] <= 32'd0;
                entry_imm[i]        <= 32'd0; entry_pc[i]         <= 32'd0;
                entry_use_pc[i]     <= 1'b0; entry_use_imm[i]    <= 1'b0;
                entry_funct3[i]     <= 3'd0; entry_is_branch[i]  <= 1'b0;
                entry_jal[i]        <= 1'b0; entry_jalr[i]       <= 1'b0;
                entry_wb_sel[i]     <= 2'd0;
                entry_mem_read[i]   <= 1'b0; entry_mem_write[i]  <= 1'b0;
            end
        end else if (flush) begin
            for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
                entry_valid[i] <= 1'b0;
            end
        end else begin
            if (cdb_valid) begin
                for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
                    if (entry_valid[i]) begin
                        if (!entry_src1_ready[i] && entry_src1_tag[i] == cdb_tag) begin
                            entry_src1_ready[i] <= 1'b1;
                            entry_src1_value[i] <= cdb_value;
                        end
                        if (!entry_src2_ready[i] && entry_src2_tag[i] == cdb_tag) begin
                            entry_src2_ready[i] <= 1'b1;
                            entry_src2_value[i] <= cdb_value;
                        end
                    end
                end
            end
            // Use REGISTERED ready_idx_r — not the combinatorial ready_idx
            if (dispatch_valid && dispatch_ack)
                entry_valid[ready_idx_r] <= 1'b0;
            if (issue_valid && found_free && !rs_full) begin
                entry_valid[free_idx] <= 1'b1;
                entry_rob_tag[free_idx] <= issue_rob_tag;
                entry_alu_op[free_idx] <= issue_alu_op;
                entry_src1_ready[free_idx] <= issue_src1_ready;
                entry_src1_tag[free_idx] <= issue_src1_tag;
                entry_src1_value[free_idx] <= issue_src1_value;
                entry_src2_ready[free_idx] <= issue_src2_ready;
                entry_src2_tag[free_idx] <= issue_src2_tag;
                entry_src2_value[free_idx] <= issue_src2_value;
                entry_imm[free_idx] <= issue_imm;
                entry_pc[free_idx] <= issue_pc;
                entry_use_pc[free_idx] <= issue_use_pc;
                entry_use_imm[free_idx] <= issue_use_imm;
                entry_funct3[free_idx] <= issue_funct3;
                entry_is_branch[free_idx] <= issue_is_branch;
                entry_jal[free_idx] <= issue_jal;
                entry_jalr[free_idx] <= issue_jalr;
                entry_wb_sel[free_idx] <= issue_wb_sel;
                entry_mem_read[free_idx] <= issue_mem_read;
                entry_mem_write[free_idx] <= issue_mem_write;
            end
        end
    end
endmodule
