`timescale 1ns/1ps
module microprocessor_tb();
    reg clk;
    reg rst;
    wire [3:0] led;

    microprocessor uut (.clk(clk), .rst(rst), .led(led));

    always #5 clk = ~clk;

    integer cycle_count;

    // Minimal cycle tracking
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count <= cycle_count + 1;
        end
    end

    initial begin
        clk = 0; rst = 1; cycle_count = 0;
        #27; rst = 0;

        wait(uut.u_core.halted || uut.u_core.trap_flag);
        #30;

        $display("");
        $display("================================================================");
        $display("     OOO RV32I CORE VERIFICATION REPORT (Mixed-ILP)");
        $display("================================================================");
        $display("");
        $display("--- Performance Counters ---");
        $display("  Total Cycles      : %0d", uut.u_core.total_cycles);
        $display("  Stall Cycles      : %0d", uut.u_core.stall_cycles);
        $display("  Retired Instrs    : %0d", uut.u_core.instr_count);
        $display("  IPC               : %0.2f", 1.0 * uut.u_core.instr_count / uut.u_core.total_cycles);
        $display("  CPI               : %0.2f", 1.0 * uut.u_core.total_cycles / uut.u_core.instr_count);
        $display("  Halted            : %b", uut.u_core.halted);

        $display("");
        $display("--- Final Register State (Non-Zero) ---");
        for (integer j = 1; j < 32; j = j + 1) begin
            if (uut.u_core.u_regfile.register[j] !== 32'd0) begin
                $display("  x%-2d = %0d (0x%08h)", j, uut.u_core.u_regfile.register[j], uut.u_core.u_regfile.register[j]);
            end
        end

        $display("");
        $display("================================================================");
        $display("          *** SIMULATION COMPLETED SUCCESSFULLY ***");
        $display("================================================================");
        $display("");
        $finish;
    end

    initial begin #100000; $display("\n!!! TIMEOUT !!!"); $finish; end

    initial begin
        $dumpfile("microprocessor.vcd");
        $dumpvars(0, microprocessor_tb);
    end
endmodule
