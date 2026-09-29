module core (
    input wire clk, input wire rst,
    input wire data_mem_valid, input wire instruc_mem_valid,
    input wire [31:0] instruction, input wire [31:0] load_data_in,
    output wire load_signal, output wire data_mem_we_re,
    output wire data_mem_request, output wire [3:0] mask_singal,
    output wire [31:0] store_data_out, output wire [31:0] alu_out_address,
    output wire [31:0] pc_address, output wire halted_debug, output wire trap_debug,
    output wire [31:0] total_cycles_debug, output wire [31:0] stall_cycles_debug,
    output wire [31:0] instr_count_debug
);
    reg [31:0] total_cycles, stall_cycles, instr_count;
    reg halted, trap_flag;
    reg [31:0] trap_cause_r, trap_pc_r, pc_reg;

    // Wire declarations (inlined from core_ooo_wires.vh)
    wire [31:0] if_id_pc, if_id_instruction;
    wire if_id_valid;
    wire [4:0] dec_rs1_addr, dec_rs2_addr, dec_rd;
    wire [2:0] dec_funct3;
    wire [31:0] dec_imm;
    wire [3:0] dec_alu_op;
    wire [1:0] dec_wb_sel;
    wire dec_reg_write, dec_mem_read, dec_mem_write, dec_use_pc, dec_use_imm;
    wire dec_branch, dec_jal, dec_jalr, dec_rs1_used, dec_rs2_used;
    wire dec_illegal, dec_ecall, dec_ebreak;
    wire [31:0] rf_rs1_data, rf_rs2_data;
    wire rat_rs1_valid, rat_rs2_valid;
    wire [1:0] rat_rs1_tag, rat_rs2_tag;
    wire [1:0] rob_read_tag_rs1, rob_read_tag_rs2;
    wire rob_read_ready_rs1, rob_read_ready_rs2;
    wire [31:0] rob_read_value_rs1, rob_read_value_rs2;
    wire [1:0] rob_alloc_tag;
    wire rob_alloc_ready, rob_alloc_req;
    wire rat_rename_en;
    wire [4:0] rat_rename_rd;
    wire [1:0] rat_rename_tag;
    wire alu_rs_full, load_rs_full, store_rs_full;
    wire dispatch_stall;
    wire [4:0] rob_alloc_rd_w;
    wire [31:0] rob_alloc_pc_w;
    wire rob_alloc_is_store_w, rob_alloc_is_load_w, rob_alloc_is_branch_w;
    wire [1:0] rob_alloc_wb_sel_w;
    wire rob_alloc_reg_write_w;
    wire [2:0] rob_alloc_funct3_w;
    wire rob_alloc_ecall_w, rob_alloc_ebreak_w, rob_alloc_illegal_w;
    wire alu_rs_issue;
    wire [1:0] alu_rs_rob_tag;
    wire [3:0] alu_rs_alu_op;
    wire alu_rs_s1_rdy, alu_rs_s2_rdy;
    wire [1:0] alu_rs_s1_tag, alu_rs_s2_tag;
    wire [31:0] alu_rs_s1_val, alu_rs_s2_val;
    wire [31:0] alu_rs_imm, alu_rs_pc;
    wire alu_rs_use_pc, alu_rs_use_imm;
    wire [2:0] alu_rs_funct3;
    wire alu_rs_is_branch, alu_rs_jal, alu_rs_jalr;
    wire [1:0] alu_rs_wb_sel;
    wire ld_rs_issue;
    wire [1:0] ld_rs_rob_tag;
    wire [3:0] ld_rs_alu_op;
    wire ld_rs_s1_rdy, ld_rs_s2_rdy;
    wire [1:0] ld_rs_s1_tag, ld_rs_s2_tag;
    wire [31:0] ld_rs_s1_val, ld_rs_s2_val;
    wire [31:0] ld_rs_imm, ld_rs_pc;
    wire [2:0] ld_rs_funct3;
    wire [1:0] ld_rs_wb_sel;
    wire st_rs_issue;
    wire [1:0] st_rs_rob_tag;
    wire [3:0] st_rs_alu_op;
    wire st_rs_s1_rdy, st_rs_s2_rdy;
    wire [1:0] st_rs_s1_tag, st_rs_s2_tag;
    wire [31:0] st_rs_s1_val, st_rs_s2_val;
    wire [31:0] st_rs_imm, st_rs_pc;
    wire [2:0] st_rs_funct3;
    wire alu_d_valid, alu_d_ack;
    wire [1:0] alu_d_rob_tag;
    wire [3:0] alu_d_alu_op;
    wire [31:0] alu_d_s1, alu_d_s2, alu_d_imm, alu_d_pc;
    wire alu_d_use_pc, alu_d_use_imm;
    wire [2:0] alu_d_funct3;
    wire alu_d_is_branch, alu_d_jal, alu_d_jalr;
    wire [1:0] alu_d_wb_sel;
    wire alu_d_mem_read, alu_d_mem_write;
    wire ld_d_valid, ld_d_ack;
    wire [1:0] ld_d_rob_tag;
    wire [31:0] ld_d_s1, ld_d_s2, ld_d_imm, ld_d_pc;
    wire [2:0] ld_d_funct3;
    wire [1:0] ld_d_wb_sel;
    wire ld_d_mem_read;
    wire st_d_valid, st_d_ack;
    wire [1:0] st_d_rob_tag;
    wire [31:0] st_d_s1, st_d_s2, st_d_imm, st_d_pc;
    wire [2:0] st_d_funct3;
    wire st_d_mem_write;
    wire cdb_valid;
    wire [1:0] cdb_tag;
    wire [31:0] cdb_value;
    wire cdb_branch_taken;
    wire [31:0] cdb_branch_target;
    wire cdb_trap_valid;
    wire [31:0] cdb_trap_cause;
    wire [31:0] cdb_store_addr, cdb_store_data;
    wire [3:0] cdb_store_mask;
    wire cdb_alu_valid, cdb_ld_valid, cdb_st_valid;
    wire [1:0] cdb_alu_tag, cdb_ld_tag, cdb_st_tag;
    wire [31:0] cdb_alu_value, cdb_ld_value;
    wire cdb_alu_bt, cdb_alu_tv;
    wire [31:0] cdb_alu_btgt, cdb_alu_tc;
    wire [31:0] cdb_st_addr, cdb_st_data;
    wire [3:0] cdb_st_mask;
    wire commit_valid, commit_reg_write, commit_is_store, commit_is_branch;
    wire commit_branch_taken, commit_trap_valid, commit_ack;
    wire [4:0] commit_rd;
    wire [31:0] commit_value, commit_store_addr, commit_store_data;
    wire [3:0] commit_store_mask;
    wire [2:0] commit_funct3;
    wire [31:0] commit_branch_target, commit_pc, commit_trap_cause;
    wire [1:0] commit_tag;
    wire rob_full, rob_empty;
    wire [31:0] fetch_next_pc;
    wire fetch_if_id_valid_next;
    wire [31:0] fetch_if_id_pc_next, fetch_if_id_instruction_next;
    wire flush_pipeline;
    wire load_mem_req;
    wire [31:0] load_mem_addr;
    wire [2:0] load_mem_funct3;

    // Branch misprediction at commit
    wire commit_mispredict = commit_valid && commit_is_branch && commit_branch_taken;
    assign flush_pipeline = commit_mispredict || (commit_valid && commit_trap_valid);

    // Commit acknowledge - always accept when valid
    assign commit_ack = commit_valid && !halted;

    // Fetch stage
    rv32i_fetch_stage u_fetch(
        .current_pc(pc_reg), .instr_valid(instruc_mem_valid),
        .instruction(instruction),
        .if_id_valid_current(if_id_valid), .if_id_pc_current(if_id_pc),
        .if_id_instruction_current(if_id_instruction),
        .trap_flush(flush_pipeline), .branch_taken(1'b0),
        .branch_target(32'd0), .stall(dispatch_stall),
        .next_pc(fetch_next_pc), .if_id_valid_next(fetch_if_id_valid_next),
        .if_id_pc_next(fetch_if_id_pc_next),
        .if_id_instruction_next(fetch_if_id_instruction_next)
    );

    rv32i_if_id_reg u_if_id(
        .clk(clk), .rst(rst), .enable(!halted && !dispatch_stall),
        .valid_in(fetch_if_id_valid_next), .pc_in(fetch_if_id_pc_next),
        .instruction_in(fetch_if_id_instruction_next),
        .valid(if_id_valid), .pc(if_id_pc), .instruction(if_id_instruction)
    );

    rv32i_decode_stage u_decode(
        .instruction(if_id_instruction),
        .rs1_addr(dec_rs1_addr), .rs2_addr(dec_rs2_addr), .rd_addr(dec_rd),
        .funct3(dec_funct3), .imm(dec_imm), .alu_op(dec_alu_op),
        .wb_sel(dec_wb_sel), .reg_write(dec_reg_write),
        .mem_read(dec_mem_read), .mem_write(dec_mem_write),
        .use_pc(dec_use_pc), .use_imm(dec_use_imm),
        .branch(dec_branch), .jal(dec_jal), .jalr(dec_jalr),
        .rs1_used(dec_rs1_used), .rs2_used(dec_rs2_used),
        .illegal(dec_illegal), .ecall(dec_ecall), .ebreak(dec_ebreak)
    );

    registerfile u_regfile(
        .clk(clk), .rst(rst),
        .en(commit_valid && commit_reg_write && commit_ack && !commit_trap_valid),
        .rs1(dec_rs1_addr), .rs2(dec_rs2_addr),
        .rd(commit_rd), .data(commit_value),
        .op_a(rf_rs1_data), .op_b(rf_rs2_data)
    );

    rat u_rat(
        .clk(clk), .rst(rst),
        .rename_en(rat_rename_en), .rename_rd(rat_rename_rd),
        .rename_tag(rat_rename_tag),
        .lookup_rs1(dec_rs1_addr), .lookup_rs1_valid(rat_rs1_valid),
        .lookup_rs1_tag(rat_rs1_tag),
        .lookup_rs2(dec_rs2_addr), .lookup_rs2_valid(rat_rs2_valid),
        .lookup_rs2_tag(rat_rs2_tag),
        .clear_en(commit_valid && commit_reg_write && commit_ack && !commit_trap_valid),
        .clear_rd(commit_rd), .clear_tag(commit_tag),
        .flush(flush_pipeline)
    );

    rob u_rob(
        .clk(clk), .rst(rst),
        .alloc_req(rob_alloc_req), .alloc_rd(rob_alloc_rd_w),
        .alloc_pc(rob_alloc_pc_w), .alloc_is_store(rob_alloc_is_store_w),
        .alloc_is_load(rob_alloc_is_load_w), .alloc_is_branch(rob_alloc_is_branch_w),
        .alloc_wb_sel(rob_alloc_wb_sel_w), .alloc_reg_write(rob_alloc_reg_write_w),
        .alloc_funct3(rob_alloc_funct3_w),
        .alloc_ecall(rob_alloc_ecall_w), .alloc_ebreak(rob_alloc_ebreak_w),
        .alloc_illegal(rob_alloc_illegal_w),
        .alloc_tag(rob_alloc_tag), .alloc_ready(rob_alloc_ready),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .cdb_branch_taken(cdb_branch_taken), .cdb_branch_target(cdb_branch_target),
        .cdb_trap_valid(cdb_trap_valid), .cdb_trap_cause(cdb_trap_cause),
        .cdb_store_addr(cdb_store_addr), .cdb_store_data(cdb_store_data),
        .cdb_store_mask(cdb_store_mask),
        .commit_valid(commit_valid), .commit_rd(commit_rd),
        .commit_value(commit_value), .commit_reg_write(commit_reg_write),
        .commit_is_store(commit_is_store), .commit_store_addr(commit_store_addr),
        .commit_store_data(commit_store_data), .commit_store_mask(commit_store_mask),
        .commit_funct3(commit_funct3), .commit_is_branch(commit_is_branch),
        .commit_branch_taken(commit_branch_taken),
        .commit_branch_target(commit_branch_target),
        .commit_pc(commit_pc), .commit_trap_valid(commit_trap_valid),
        .commit_trap_cause(commit_trap_cause), .commit_tag(commit_tag),
        .commit_ack(commit_ack),
        .flush(flush_pipeline),
        .read_tag(rob_read_tag_rs1), .read_ready(rob_read_ready_rs1),
        .read_value(rob_read_value_rs1),
        .read2_tag(rob_read_tag_rs2), .read2_ready(rob_read_ready_rs2),
        .read2_value(rob_read_value_rs2),
        .rob_full(rob_full), .rob_empty(rob_empty)
    );

    ooo_dispatch u_dispatch(
        .clk(clk), .rst(rst),
        .id_valid(if_id_valid && !flush_pipeline), .id_pc(if_id_pc),
        .id_rs1_addr(dec_rs1_addr), .id_rs2_addr(dec_rs2_addr),
        .id_rd(dec_rd), .id_funct3(dec_funct3), .id_imm(dec_imm),
        .id_alu_op(dec_alu_op), .id_wb_sel(dec_wb_sel),
        .id_reg_write(dec_reg_write), .id_mem_read(dec_mem_read),
        .id_mem_write(dec_mem_write), .id_use_pc(dec_use_pc),
        .id_use_imm(dec_use_imm), .id_branch(dec_branch),
        .id_jal(dec_jal), .id_jalr(dec_jalr),
        .id_rs1_used(dec_rs1_used), .id_rs2_used(dec_rs2_used),
        .id_illegal(dec_illegal), .id_ecall(dec_ecall), .id_ebreak(dec_ebreak),
        .rf_rs1_data(rf_rs1_data), .rf_rs2_data(rf_rs2_data),
        .rat_rs1_valid(rat_rs1_valid), .rat_rs1_tag(rat_rs1_tag),
        .rat_rs2_valid(rat_rs2_valid), .rat_rs2_tag(rat_rs2_tag),
        .rob_read_tag_rs1(rob_read_tag_rs1), .rob_read_ready_rs1(rob_read_ready_rs1),
        .rob_read_value_rs1(rob_read_value_rs1),
        .rob_read_tag_rs2(rob_read_tag_rs2), .rob_read_ready_rs2(rob_read_ready_rs2),
        .rob_read_value_rs2(rob_read_value_rs2),
        .rob_alloc_tag(rob_alloc_tag), .rob_alloc_ready(rob_alloc_ready),
        .rob_alloc_req(rob_alloc_req),
        .rat_rename_en(rat_rename_en), .rat_rename_rd(rat_rename_rd),
        .rat_rename_tag(rat_rename_tag),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .alu_rs_full(alu_rs_full), .load_rs_full(load_rs_full),
        .store_rs_full(store_rs_full),
        .alu_rs_issue(alu_rs_issue), .alu_rs_rob_tag(alu_rs_rob_tag),
        .alu_rs_alu_op(alu_rs_alu_op),
        .alu_rs_src1_ready(alu_rs_s1_rdy), .alu_rs_src1_tag(alu_rs_s1_tag),
        .alu_rs_src1_value(alu_rs_s1_val),
        .alu_rs_src2_ready(alu_rs_s2_rdy), .alu_rs_src2_tag(alu_rs_s2_tag),
        .alu_rs_src2_value(alu_rs_s2_val),
        .alu_rs_imm(alu_rs_imm), .alu_rs_pc(alu_rs_pc),
        .alu_rs_use_pc(alu_rs_use_pc), .alu_rs_use_imm(alu_rs_use_imm),
        .alu_rs_funct3(alu_rs_funct3), .alu_rs_is_branch(alu_rs_is_branch),
        .alu_rs_jal(alu_rs_jal), .alu_rs_jalr(alu_rs_jalr),
        .alu_rs_wb_sel(alu_rs_wb_sel),
        .load_rs_issue(ld_rs_issue), .load_rs_rob_tag(ld_rs_rob_tag),
        .load_rs_alu_op(ld_rs_alu_op),
        .load_rs_src1_ready(ld_rs_s1_rdy), .load_rs_src1_tag(ld_rs_s1_tag),
        .load_rs_src1_value(ld_rs_s1_val),
        .load_rs_src2_ready(ld_rs_s2_rdy), .load_rs_src2_tag(ld_rs_s2_tag),
        .load_rs_src2_value(ld_rs_s2_val),
        .load_rs_imm(ld_rs_imm), .load_rs_pc(ld_rs_pc),
        .load_rs_funct3(ld_rs_funct3), .load_rs_wb_sel(ld_rs_wb_sel),
        .store_rs_issue(st_rs_issue), .store_rs_rob_tag(st_rs_rob_tag),
        .store_rs_alu_op(st_rs_alu_op),
        .store_rs_src1_ready(st_rs_s1_rdy), .store_rs_src1_tag(st_rs_s1_tag),
        .store_rs_src1_value(st_rs_s1_val),
        .store_rs_src2_ready(st_rs_s2_rdy), .store_rs_src2_tag(st_rs_s2_tag),
        .store_rs_src2_value(st_rs_s2_val),
        .store_rs_imm(st_rs_imm), .store_rs_pc(st_rs_pc),
        .store_rs_funct3(st_rs_funct3),
        .rob_alloc_rd(rob_alloc_rd_w), .rob_alloc_pc(rob_alloc_pc_w),
        .rob_alloc_is_store(rob_alloc_is_store_w),
        .rob_alloc_is_load(rob_alloc_is_load_w),
        .rob_alloc_is_branch(rob_alloc_is_branch_w),
        .rob_alloc_wb_sel(rob_alloc_wb_sel_w),
        .rob_alloc_reg_write(rob_alloc_reg_write_w),
        .rob_alloc_funct3(rob_alloc_funct3_w),
        .rob_alloc_ecall(rob_alloc_ecall_w),
        .rob_alloc_ebreak(rob_alloc_ebreak_w),
        .rob_alloc_illegal(rob_alloc_illegal_w),
        .dispatch_stall(dispatch_stall)
    );

    // ALU Reservation Station (2 entries)
    reservation_station #(.NUM_ENTRIES(2)) u_alu_rs(
        .clk(clk), .rst(rst),
        .issue_valid(alu_rs_issue), .issue_rob_tag(alu_rs_rob_tag),
        .issue_alu_op(alu_rs_alu_op),
        .issue_src1_ready(alu_rs_s1_rdy), .issue_src1_tag(alu_rs_s1_tag),
        .issue_src1_value(alu_rs_s1_val),
        .issue_src2_ready(alu_rs_s2_rdy), .issue_src2_tag(alu_rs_s2_tag),
        .issue_src2_value(alu_rs_s2_val),
        .issue_imm(alu_rs_imm), .issue_pc(alu_rs_pc),
        .issue_use_pc(alu_rs_use_pc), .issue_use_imm(alu_rs_use_imm),
        .issue_funct3(alu_rs_funct3), .issue_is_branch(alu_rs_is_branch),
        .issue_jal(alu_rs_jal), .issue_jalr(alu_rs_jalr),
        .issue_wb_sel(alu_rs_wb_sel),
        .issue_mem_read(1'b0), .issue_mem_write(1'b0),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .dispatch_valid(alu_d_valid), .dispatch_rob_tag(alu_d_rob_tag),
        .dispatch_alu_op(alu_d_alu_op),
        .dispatch_src1_value(alu_d_s1), .dispatch_src2_value(alu_d_s2),
        .dispatch_imm(alu_d_imm), .dispatch_pc(alu_d_pc),
        .dispatch_use_pc(alu_d_use_pc), .dispatch_use_imm(alu_d_use_imm),
        .dispatch_funct3(alu_d_funct3), .dispatch_is_branch(alu_d_is_branch),
        .dispatch_jal(alu_d_jal), .dispatch_jalr(alu_d_jalr),
        .dispatch_wb_sel(alu_d_wb_sel),
        .dispatch_mem_read(alu_d_mem_read), .dispatch_mem_write(alu_d_mem_write),
        .dispatch_ack(alu_d_ack),
        .rs_full(alu_rs_full), .flush(flush_pipeline)
    );

    // Load Reservation Station (1 entry)
    reservation_station #(.NUM_ENTRIES(1)) u_load_rs(
        .clk(clk), .rst(rst),
        .issue_valid(ld_rs_issue), .issue_rob_tag(ld_rs_rob_tag),
        .issue_alu_op(ld_rs_alu_op),
        .issue_src1_ready(ld_rs_s1_rdy), .issue_src1_tag(ld_rs_s1_tag),
        .issue_src1_value(ld_rs_s1_val),
        .issue_src2_ready(ld_rs_s2_rdy), .issue_src2_tag(ld_rs_s2_tag),
        .issue_src2_value(ld_rs_s2_val),
        .issue_imm(ld_rs_imm), .issue_pc(ld_rs_pc),
        .issue_use_pc(1'b0), .issue_use_imm(1'b1),
        .issue_funct3(ld_rs_funct3), .issue_is_branch(1'b0),
        .issue_jal(1'b0), .issue_jalr(1'b0), .issue_wb_sel(ld_rs_wb_sel),
        .issue_mem_read(1'b1), .issue_mem_write(1'b0),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .dispatch_valid(ld_d_valid), .dispatch_rob_tag(ld_d_rob_tag),
        .dispatch_alu_op(), .dispatch_src1_value(ld_d_s1),
        .dispatch_src2_value(ld_d_s2),
        .dispatch_imm(ld_d_imm), .dispatch_pc(ld_d_pc),
        .dispatch_use_pc(), .dispatch_use_imm(),
        .dispatch_funct3(ld_d_funct3), .dispatch_is_branch(),
        .dispatch_jal(), .dispatch_jalr(), .dispatch_wb_sel(ld_d_wb_sel),
        .dispatch_mem_read(ld_d_mem_read), .dispatch_mem_write(),
        .dispatch_ack(ld_d_ack),
        .rs_full(load_rs_full), .flush(flush_pipeline)
    );

    // Store Reservation Station (1 entry)
    reservation_station #(.NUM_ENTRIES(1)) u_store_rs(
        .clk(clk), .rst(rst),
        .issue_valid(st_rs_issue), .issue_rob_tag(st_rs_rob_tag),
        .issue_alu_op(st_rs_alu_op),
        .issue_src1_ready(st_rs_s1_rdy), .issue_src1_tag(st_rs_s1_tag),
        .issue_src1_value(st_rs_s1_val),
        .issue_src2_ready(st_rs_s2_rdy), .issue_src2_tag(st_rs_s2_tag),
        .issue_src2_value(st_rs_s2_val),
        .issue_imm(st_rs_imm), .issue_pc(st_rs_pc),
        .issue_use_pc(1'b0), .issue_use_imm(1'b1),
        .issue_funct3(st_rs_funct3), .issue_is_branch(1'b0),
        .issue_jal(1'b0), .issue_jalr(1'b0), .issue_wb_sel(2'b00),
        .issue_mem_read(1'b0), .issue_mem_write(1'b1),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .dispatch_valid(st_d_valid), .dispatch_rob_tag(st_d_rob_tag),
        .dispatch_alu_op(), .dispatch_src1_value(st_d_s1),
        .dispatch_src2_value(st_d_s2),
        .dispatch_imm(st_d_imm), .dispatch_pc(st_d_pc),
        .dispatch_use_pc(), .dispatch_use_imm(),
        .dispatch_funct3(st_d_funct3), .dispatch_is_branch(),
        .dispatch_jal(), .dispatch_jalr(), .dispatch_wb_sel(),
        .dispatch_mem_read(), .dispatch_mem_write(st_d_mem_write),
        .dispatch_ack(st_d_ack),
        .rs_full(store_rs_full), .flush(flush_pipeline)
    );

    // Execution units
    ooo_execute u_exec(
        .clk(clk), .rst(rst),
        .alu_disp_valid(alu_d_valid), .alu_disp_rob_tag(alu_d_rob_tag),
        .alu_disp_alu_op(alu_d_alu_op), .alu_disp_src1(alu_d_s1),
        .alu_disp_src2(alu_d_s2), .alu_disp_imm(alu_d_imm),
        .alu_disp_pc(alu_d_pc), .alu_disp_use_pc(alu_d_use_pc),
        .alu_disp_use_imm(alu_d_use_imm), .alu_disp_funct3(alu_d_funct3),
        .alu_disp_is_branch(alu_d_is_branch), .alu_disp_jal(alu_d_jal),
        .alu_disp_jalr(alu_d_jalr), .alu_disp_wb_sel(alu_d_wb_sel),
        .alu_disp_ack(alu_d_ack),
        .ld_disp_valid(ld_d_valid), .ld_disp_rob_tag(ld_d_rob_tag),
        .ld_disp_src1(ld_d_s1), .ld_disp_imm(ld_d_imm),
        .ld_disp_funct3(ld_d_funct3), .ld_disp_wb_sel(ld_d_wb_sel),
        .ld_disp_ack(ld_d_ack),
        .st_disp_valid(st_d_valid), .st_disp_rob_tag(st_d_rob_tag),
        .st_disp_src1(st_d_s1), .st_disp_src2(st_d_s2),
        .st_disp_imm(st_d_imm), .st_disp_funct3(st_d_funct3),
        .st_disp_ack(st_d_ack),
        .load_data_in(load_data_in), .data_mem_valid(data_mem_valid),
        .cdb_alu_valid(cdb_alu_valid), .cdb_alu_tag(cdb_alu_tag),
        .cdb_alu_value(cdb_alu_value), .cdb_alu_branch_taken(cdb_alu_bt),
        .cdb_alu_branch_target(cdb_alu_btgt), .cdb_alu_trap_valid(cdb_alu_tv),
        .cdb_alu_trap_cause(cdb_alu_tc),
        .cdb_ld_valid(cdb_ld_valid), .cdb_ld_tag(cdb_ld_tag),
        .cdb_ld_value(cdb_ld_value),
        .cdb_st_valid(cdb_st_valid), .cdb_st_tag(cdb_st_tag),
        .cdb_st_addr(cdb_st_addr), .cdb_st_data(cdb_st_data),
        .cdb_st_mask(cdb_st_mask),
        .load_mem_req(load_mem_req), .load_mem_addr(load_mem_addr),
        .load_mem_funct3(load_mem_funct3), .flush(flush_pipeline)
    );

    // CDB Arbiter
    cdb u_cdb(
        .alu_result_valid(cdb_alu_valid), .alu_result_tag(cdb_alu_tag),
        .alu_result_value(cdb_alu_value), .alu_branch_taken(cdb_alu_bt),
        .alu_branch_target(cdb_alu_btgt), .alu_trap_valid(cdb_alu_tv),
        .alu_trap_cause(cdb_alu_tc),
        .load_result_valid(cdb_ld_valid), .load_result_tag(cdb_ld_tag),
        .load_result_value(cdb_ld_value),
        .store_result_valid(cdb_st_valid), .store_result_tag(cdb_st_tag),
        .store_result_addr(cdb_st_addr), .store_result_data(cdb_st_data),
        .store_result_mask(cdb_st_mask),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .cdb_branch_taken(cdb_branch_taken), .cdb_branch_target(cdb_branch_target),
        .cdb_trap_valid(cdb_trap_valid), .cdb_trap_cause(cdb_trap_cause),
        .cdb_store_addr(cdb_store_addr), .cdb_store_data(cdb_store_data),
        .cdb_store_mask(cdb_store_mask),
        .alu_stall(), .load_stall(), .store_stall()
    );

    // Output assignments
    // Store commits from ROB head
    assign data_mem_we_re = commit_valid && commit_is_store && commit_ack && !commit_trap_valid;
    assign load_signal = load_mem_req;
    assign data_mem_request = load_mem_req || (commit_valid && commit_is_store && commit_ack && !commit_trap_valid);
    assign mask_singal = data_mem_we_re ? commit_store_mask : 4'b1111;
    assign store_data_out = data_mem_we_re ? commit_store_data : 32'b0;
    assign alu_out_address = data_mem_we_re ? commit_store_addr : load_mem_addr;
    assign pc_address = pc_reg;
    assign halted_debug = halted;
    assign trap_debug = trap_flag;
    assign total_cycles_debug = total_cycles;
    assign stall_cycles_debug = stall_cycles;
    assign instr_count_debug = instr_count;

    // PC, counters, trap handling
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            total_cycles<=32'd0; stall_cycles<=32'd0; instr_count<=32'd0;
            halted<=1'b0; trap_flag<=1'b0;
            trap_cause_r<=32'd0; trap_pc_r<=32'd0; pc_reg<=32'd0;
        end else if (!halted) begin
            total_cycles <= total_cycles + 32'd1;
            if (dispatch_stall) stall_cycles <= stall_cycles + 32'd1;
            if (commit_valid && commit_ack && !commit_trap_valid)
                instr_count <= instr_count + 32'd1;
            if (commit_valid && commit_trap_valid) begin
                halted<=1'b1; trap_flag<=1'b1;
                trap_cause_r<=commit_trap_cause; trap_pc_r<=commit_pc;
            end
            if (commit_mispredict)
                pc_reg <= commit_branch_target;
            else if (!dispatch_stall)
                pc_reg <= fetch_next_pc;
        end
    end
endmodule
