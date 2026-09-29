//============================================================================
// rat.v — Register Alias Table for OOO RV32I Core
//============================================================================
module rat (
    input wire        clk,
    input wire        rst,
    input  wire        rename_en,
    input  wire [4:0]  rename_rd,
    input  wire [1:0]  rename_tag,
    input  wire [4:0]  lookup_rs1,
    output wire        lookup_rs1_valid,
    output wire [1:0]  lookup_rs1_tag,
    input  wire [4:0]  lookup_rs2,
    output wire        lookup_rs2_valid,
    output wire [1:0]  lookup_rs2_tag,
    input  wire        clear_en,
    input  wire [4:0]  clear_rd,
    input  wire [1:0]  clear_tag,
    input  wire        flush
);

    reg        rat_valid [0:31];
    reg [1:0]  rat_tag   [0:31];
    integer i;

    assign lookup_rs1_valid = (lookup_rs1 != 5'd0) ? rat_valid[lookup_rs1] : 1'b0;
    assign lookup_rs1_tag   = rat_tag[lookup_rs1];
    assign lookup_rs2_valid = (lookup_rs2 != 5'd0) ? rat_valid[lookup_rs2] : 1'b0;
    assign lookup_rs2_tag   = rat_tag[lookup_rs2];

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                rat_valid[i] <= 1'b0;
                rat_tag[i]   <= 2'd0;
            end
        end else if (flush) begin
            for (i = 0; i < 32; i = i + 1) begin
                rat_valid[i] <= 1'b0;
                rat_tag[i]   <= 2'd0;
            end
        end else begin
            if (clear_en && clear_rd != 5'd0) begin
                if (rat_valid[clear_rd] && rat_tag[clear_rd] == clear_tag) begin
                    rat_valid[clear_rd] <= 1'b0;
                end
            end
            if (rename_en && rename_rd != 5'd0) begin
                rat_valid[rename_rd] <= 1'b1;
                rat_tag[rename_rd]   <= rename_tag;
            end
        end
    end
endmodule
