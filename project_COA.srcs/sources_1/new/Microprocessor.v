module microprocessor (
    input wire clk,
    input wire rst,
    output wire [3:0] led
);
    wire rst_n;
    wire [31:0] instruction_data, pc_address, load_data_out;
    wire [31:0] alu_out_address, store_data;
    wire [3:0] mask;
    wire instruc_mem_valid, data_mem_valid, data_mem_we_re, data_mem_request;
    wire load_signal, cpu_halted, cpu_trap;
    wire [31:0] total_cycles_dbg, stall_cycles_dbg, instr_count_dbg;

    assign rst_n = ~rst;

    instruc_mem_top #(
        .INIT_MEM(1),
        .INIT_FILE("C:/Vivado Projects/OoO_execution/OoO_execution.srcs/sim_1/new/instr.mem")
    ) u_instruction_memory (
        .clk(clk), .rst(rst_n), .we_re(1'b0), .request(1'b1),
        .mask(4'b1111), .address(pc_address[9:2]),
        .data_in(32'b0), .valid(instruc_mem_valid), .data_out(instruction_data)
    );

    core u_core (
        .clk(clk), .rst(rst_n),
        .instruction(instruction_data), .load_data_in(load_data_out),
        .mask_singal(mask), .load_signal(load_signal),
        .data_mem_we_re(data_mem_we_re), .data_mem_request(data_mem_request),
        .instruc_mem_valid(instruc_mem_valid), .data_mem_valid(data_mem_valid),
        .store_data_out(store_data), .pc_address(pc_address),
        .alu_out_address(alu_out_address),
        .halted_debug(cpu_halted), .trap_debug(cpu_trap),
        .total_cycles_debug(total_cycles_dbg),
        .stall_cycles_debug(stall_cycles_dbg),
        .instr_count_debug(instr_count_dbg)
    );

    data_mem_top u_data_memory (
        .clk(clk), .rst(rst_n),
        .we_re(data_mem_we_re), .request(data_mem_request),
        .address(alu_out_address[9:2]), .data_in(store_data),
        .mask(mask), .load(load_signal),
        .valid(data_mem_valid), .data_out(load_data_out)
    );

    assign led[0] = cpu_halted;              // ON = program finished
    assign led[1] = instr_count_dbg[3];     // ON = ≥8 instructions retired
    assign led[2] = instr_count_dbg[2];     // ON = ≥4 instructions retired
    assign led[3] = |total_cycles_dbg[7:4]; // ON = ≥16 cycles elapsed

    // =========================================================================
    //  ILA Debug Core (for FPGA implementation)
    //  Uncomment the following block after generating the ILA IP in Vivado:
    //    1. Open Vivado -> IP Catalog -> ILA (Integrated Logic Analyzer)
    //    2. Set: Number of probes = 8, Sample data depth = 1024
    //    3. Probe widths: p0=32, p1=32, p2=32, p3=1, p4=1, p5=32, p6=32, p7=4
    //    4. Generate the IP, then uncomment below
    // =========================================================================
    // ila_0 u_ila (
    //     .clk(clk),
    //     .probe0(pc_address),           // 32-bit: Program Counter
    //     .probe1(instruction_data),     // 32-bit: Current Instruction
    //     .probe2(alu_out_address),      // 32-bit: ALU/Memory Address
    //     .probe3(cpu_halted),           // 1-bit:  Halted flag
    //     .probe4(cpu_trap),             // 1-bit:  Trap flag
    //     .probe5(total_cycles_dbg),     // 32-bit: Total Cycles
    //     .probe6(instr_count_dbg),      // 32-bit: Instruction Count
    //     .probe7(led)                   // 4-bit:  LED output
    // );

    // =========================================================================
    //  Alternative: Use MARK_DEBUG attributes for ILA auto-insertion
    //  Add these to your XDC or use Vivado's Set Up Debug wizard
    // =========================================================================
    (* MARK_DEBUG = "true" *) wire [31:0] dbg_pc = pc_address;
    (* MARK_DEBUG = "true" *) wire [31:0] dbg_instr = instruction_data;
    (* MARK_DEBUG = "true" *) wire [31:0] dbg_cycles = total_cycles_dbg;
    (* MARK_DEBUG = "true" *) wire [31:0] dbg_icount = instr_count_dbg;
    (* MARK_DEBUG = "true" *) wire        dbg_halted = cpu_halted;
    (* MARK_DEBUG = "true" *) wire        dbg_trap = cpu_trap;
    (* MARK_DEBUG = "true" *) wire [31:0] dbg_stalls = stall_cycles_dbg;
    (* MARK_DEBUG = "true" *) wire        dbg_we = data_mem_we_re;

endmodule
