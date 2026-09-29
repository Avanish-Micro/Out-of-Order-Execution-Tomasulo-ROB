module ooo_execute (
    input wire clk, input wire rst,
    // ALU RS dispatch
    input wire alu_disp_valid, input wire [1:0] alu_disp_rob_tag,
    input wire [3:0] alu_disp_alu_op, input wire [31:0] alu_disp_src1,
    input wire [31:0] alu_disp_src2, input wire [31:0] alu_disp_imm,
    input wire [31:0] alu_disp_pc, input wire alu_disp_use_pc,
    input wire alu_disp_use_imm, input wire [2:0] alu_disp_funct3,
    input wire alu_disp_is_branch, input wire alu_disp_jal,
    input wire alu_disp_jalr, input wire [1:0] alu_disp_wb_sel,
    output wire alu_disp_ack,
    // Load RS dispatch
    input wire ld_disp_valid, input wire [1:0] ld_disp_rob_tag,
    input wire [31:0] ld_disp_src1, input wire [31:0] ld_disp_imm,
    input wire [2:0] ld_disp_funct3, input wire [1:0] ld_disp_wb_sel,
    output wire ld_disp_ack,
    // Store RS dispatch
    input wire st_disp_valid, input wire [1:0] st_disp_rob_tag,
    input wire [31:0] st_disp_src1, input wire [31:0] st_disp_src2,
    input wire [31:0] st_disp_imm, input wire [2:0] st_disp_funct3,
    output wire st_disp_ack,
    // Data memory interface
    input wire [31:0] load_data_in, input wire data_mem_valid,
    // CDB outputs
    output wire cdb_alu_valid, output wire [1:0] cdb_alu_tag,
    output wire [31:0] cdb_alu_value, output wire cdb_alu_branch_taken,
    output wire [31:0] cdb_alu_branch_target, output wire cdb_alu_trap_valid,
    output wire [31:0] cdb_alu_trap_cause,
    output wire cdb_ld_valid, output wire [1:0] cdb_ld_tag,
    output wire [31:0] cdb_ld_value,
    output wire cdb_st_valid, output wire [1:0] cdb_st_tag,
    output wire [31:0] cdb_st_addr, output wire [31:0] cdb_st_data,
    output wire [3:0] cdb_st_mask,
    // Memory request (for loads)
    output wire load_mem_req, output wire [31:0] load_mem_addr,
    output wire [2:0] load_mem_funct3,
    input wire flush
);
    localparam TRAP_INST_MISALIGNED=32'd0, TRAP_ILLEGAL=32'd2,
               TRAP_BREAK=32'd3, TRAP_LOAD_MIS=32'd4, TRAP_STORE_MIS=32'd6, TRAP_ECALL=32'd11;

    // ALU execution - single cycle combinational
    wire [31:0] alu_op_a = alu_disp_use_pc ? alu_disp_pc : alu_disp_src1;
    wire [31:0] alu_op_b = alu_disp_use_imm ? alu_disp_imm : alu_disp_src2;
    wire [31:0] alu_result;
    alu u_exec_alu(.a_i(alu_op_a),.b_i(alu_op_b),.op_i(alu_disp_alu_op),.res_o(alu_result));

    // Branch comparison
    reg branch_cmp;
    always @(*) begin
        case(alu_disp_funct3)
            3'b000: branch_cmp = (alu_disp_src1 == alu_disp_src2);
            3'b001: branch_cmp = (alu_disp_src1 != alu_disp_src2);
            3'b100: branch_cmp = ($signed(alu_disp_src1) < $signed(alu_disp_src2));
            3'b101: branch_cmp = ($signed(alu_disp_src1) >= $signed(alu_disp_src2));
            3'b110: branch_cmp = (alu_disp_src1 < alu_disp_src2);
            3'b111: branch_cmp = (alu_disp_src1 >= alu_disp_src2);
            default: branch_cmp = 1'b0;
        endcase
    end

    wire alu_ctrl_taken = alu_disp_valid && (alu_disp_jal || alu_disp_jalr ||
                          (alu_disp_is_branch && branch_cmp));
    wire [31:0] alu_branch_tgt = alu_disp_jalr ? {alu_result[31:1],1'b0} : alu_result;
    wire alu_pc_mis = alu_ctrl_taken && (alu_branch_tgt[1:0] != 2'b00);

    // ALU result value: for JAL/JALR use PC+4
    wire [31:0] alu_out_val = (alu_disp_wb_sel == 2'b10) ? (alu_disp_pc + 32'd4) : alu_result;

    assign cdb_alu_valid = alu_disp_valid;
    assign cdb_alu_tag = alu_disp_rob_tag;
    assign cdb_alu_value = alu_out_val;
    assign cdb_alu_branch_taken = alu_ctrl_taken && !alu_pc_mis;
    assign cdb_alu_branch_target = alu_branch_tgt;
    assign cdb_alu_trap_valid = alu_disp_valid && alu_pc_mis;
    assign cdb_alu_trap_cause = TRAP_INST_MISALIGNED;
    assign alu_disp_ack = alu_disp_valid && !flush;

    // Load execution - 1 cycle latency
    reg ld_pending;
    reg [1:0] ld_pending_tag;
    reg [2:0] ld_pending_funct3;
    reg [1:0] ld_pending_addr_low;

    wire [31:0] ld_addr = ld_disp_src1 + ld_disp_imm;
    assign load_mem_req = ld_disp_valid && !ld_pending && !flush;
    assign load_mem_addr = ld_addr;
    assign load_mem_funct3 = ld_disp_funct3;
    assign ld_disp_ack = ld_disp_valid && !ld_pending && !flush;

    // Load format
    reg [31:0] ld_formatted;
    always @(*) begin
        case(ld_pending_funct3)
            3'b000: case(ld_pending_addr_low)
                2'b00: ld_formatted={{24{load_data_in[7]}},load_data_in[7:0]};
                2'b01: ld_formatted={{24{load_data_in[15]}},load_data_in[15:8]};
                2'b10: ld_formatted={{24{load_data_in[23]}},load_data_in[23:16]};
                default: ld_formatted={{24{load_data_in[31]}},load_data_in[31:24]};
            endcase
            3'b001: case(ld_pending_addr_low)
                2'b00: ld_formatted={{16{load_data_in[15]}},load_data_in[15:0]};
                2'b01: ld_formatted={{16{load_data_in[23]}},load_data_in[23:8]};
                default: ld_formatted={{16{load_data_in[31]}},load_data_in[31:16]};
            endcase
            3'b010: ld_formatted=load_data_in;
            3'b100: case(ld_pending_addr_low)
                2'b00: ld_formatted={24'b0,load_data_in[7:0]};
                2'b01: ld_formatted={24'b0,load_data_in[15:8]};
                2'b10: ld_formatted={24'b0,load_data_in[23:16]};
                default: ld_formatted={24'b0,load_data_in[31:24]};
            endcase
            default: case(ld_pending_addr_low)
                2'b00: ld_formatted={16'b0,load_data_in[15:0]};
                2'b01: ld_formatted={16'b0,load_data_in[23:8]};
                default: ld_formatted={16'b0,load_data_in[31:16]};
            endcase
        endcase
    end

    assign cdb_ld_valid = ld_pending;
    assign cdb_ld_tag = ld_pending_tag;
    assign cdb_ld_value = ld_formatted;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            ld_pending <= 1'b0;
            ld_pending_tag <= 2'd0;
            ld_pending_funct3 <= 3'd0;
            ld_pending_addr_low <= 2'd0;
        end else if (flush) begin
            ld_pending <= 1'b0;
        end else begin
            if (ld_disp_valid && !ld_pending && !flush) begin
                ld_pending <= 1'b1;
                ld_pending_tag <= ld_disp_rob_tag;
                ld_pending_funct3 <= ld_disp_funct3;
                ld_pending_addr_low <= ld_addr[1:0];
            end else begin
                ld_pending <= 1'b0;
            end
        end
    end

    // Store execution - compute address, mask, aligned data
    wire [31:0] st_addr = st_disp_src1 + st_disp_imm;
    reg [3:0] st_mask_r;
    reg [31:0] st_data_r;
    always @(*) begin
        case(st_disp_funct3)
            3'b000: begin
                case(st_addr[1:0])
                    2'b00: begin st_mask_r=4'b0001; st_data_r={24'b0,st_disp_src2[7:0]}; end
                    2'b01: begin st_mask_r=4'b0010; st_data_r={16'b0,st_disp_src2[7:0],8'b0}; end
                    2'b10: begin st_mask_r=4'b0100; st_data_r={8'b0,st_disp_src2[7:0],16'b0}; end
                    default: begin st_mask_r=4'b1000; st_data_r={st_disp_src2[7:0],24'b0}; end
                endcase
            end
            3'b001: begin
                case(st_addr[1:0])
                    2'b00: begin st_mask_r=4'b0011; st_data_r={16'b0,st_disp_src2[15:0]}; end
                    2'b01: begin st_mask_r=4'b0110; st_data_r={8'b0,st_disp_src2[15:0],8'b0}; end
                    default: begin st_mask_r=4'b1100; st_data_r={st_disp_src2[15:0],16'b0}; end
                endcase
            end
            default: begin st_mask_r=4'b1111; st_data_r=st_disp_src2; end
        endcase
    end

    assign cdb_st_valid = st_disp_valid && !flush;
    assign cdb_st_tag = st_disp_rob_tag;
    assign cdb_st_addr = st_addr;
    assign cdb_st_data = st_data_r;
    assign cdb_st_mask = st_mask_r;
    assign st_disp_ack = st_disp_valid && !flush;
endmodule
