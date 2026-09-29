# ila_setup.tcl - Run in Vivado Tcl Console to create ILA IP
# Usage: source ila_setup.tcl

# Create ILA IP with 8 probes
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0

set_property -dict [list \
    CONFIG.C_PROBE7_WIDTH {4} \
    CONFIG.C_PROBE6_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {32} \
    CONFIG.C_PROBE1_WIDTH {32} \
    CONFIG.C_PROBE0_WIDTH {32} \
    CONFIG.C_NUM_OF_PROBES {8} \
    CONFIG.C_DATA_DEPTH {1024} \
    CONFIG.C_EN_STRG_QUAL {1} \
    CONFIG.ALL_PROBE_SAME_MU_CNT {2} \
] [get_ips ila_0]

generate_target all [get_ips ila_0]

puts "ILA IP created successfully!"
puts "Now uncomment the ila_0 instantiation in Microprocessor.v"
puts "Probe mapping:"
puts "  probe0 = PC (32-bit)"
puts "  probe1 = Instruction (32-bit)"
puts "  probe2 = ALU/Mem Address (32-bit)"
puts "  probe3 = Halted (1-bit)"
puts "  probe4 = Trap (1-bit)"
puts "  probe5 = Total Cycles (32-bit)"
puts "  probe6 = Instruction Count (32-bit)"
puts "  probe7 = LEDs (4-bit)"
