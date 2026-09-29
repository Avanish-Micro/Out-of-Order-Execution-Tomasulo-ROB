module rv32i_fetch_stage (
    input wire [31:0] current_pc,
    input wire instr_valid,
    input wire [31:0] instruction,
    input wire if_id_valid_current,
    input wire [31:0] if_id_pc_current,
    input wire [31:0] if_id_instruction_current,
    input wire trap_flush,
    input wire branch_taken,
    input wire [31:0] branch_target,
    input wire stall,

    output reg [31:0] next_pc,
    output reg if_id_valid_next,
    output reg [31:0] if_id_pc_next,
    output reg [31:0] if_id_instruction_next
);

    always @(*) begin
        next_pc = current_pc;
        if_id_valid_next = if_id_valid_current;
        if_id_pc_next = if_id_pc_current;
        if_id_instruction_next = if_id_instruction_current;

        if (trap_flush) begin
            if_id_valid_next = 1'b0;
            if_id_pc_next = 32'd0;
            if_id_instruction_next = 32'd0;
        end else if (branch_taken) begin
            next_pc = branch_target;
            if_id_valid_next = 1'b0;
            if_id_pc_next = 32'd0;
            if_id_instruction_next = 32'd0;
        end else if (!stall) begin
            next_pc = current_pc + 32'd4;
            if_id_valid_next = instr_valid;
            if_id_pc_next = current_pc;
            if_id_instruction_next = instruction;
        end
    end

endmodule
