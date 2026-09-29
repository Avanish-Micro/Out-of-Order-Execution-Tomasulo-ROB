# Minimal Zybo Z7-10 constraints for the soft core top-level.
# Pin selections are based on Digilent's Zybo-Z7 master XDC.

set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name sys_clk_pin -waveform {0.000 10.000} -add [get_ports clk]

set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports rst]

set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

create_debug_core u_ila ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila]
set_property C_TRIGIN_EN false [get_debug_cores u_ila]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila]
set_property port_width 1 [get_debug_ports u_ila/clk]
connect_debug_port u_ila/clk [get_nets [list clk_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila/probe0]
set_property port_width 32 [get_debug_ports u_ila/probe0]
connect_debug_port u_ila/probe0 [get_nets [list {dbg_pc[0]} {dbg_pc[10]} {dbg_pc[11]} {dbg_pc[12]} {dbg_pc[13]} {dbg_pc[14]} {dbg_pc[15]} {dbg_pc[16]} {dbg_pc[17]} {dbg_pc[18]} {dbg_pc[19]} {dbg_pc[1]} {dbg_pc[20]} {dbg_pc[21]} {dbg_pc[22]} {dbg_pc[23]} {dbg_pc[24]} {dbg_pc[25]} {dbg_pc[26]} {dbg_pc[27]} {dbg_pc[28]} {dbg_pc[29]} {dbg_pc[2]} {dbg_pc[30]} {dbg_pc[31]} {dbg_pc[3]} {dbg_pc[4]} {dbg_pc[5]} {dbg_pc[6]} {dbg_pc[7]} {dbg_pc[8]} {dbg_pc[9]}]]
create_debug_port u_ila probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila/probe1]
set_property port_width 32 [get_debug_ports u_ila/probe1]
connect_debug_port u_ila/probe1 [get_nets [list {dbg_instr[0]} {dbg_instr[10]} {dbg_instr[11]} {dbg_instr[12]} {dbg_instr[13]} {dbg_instr[14]} {dbg_instr[15]} {dbg_instr[16]} {dbg_instr[17]} {dbg_instr[18]} {dbg_instr[19]} {dbg_instr[1]} {dbg_instr[20]} {dbg_instr[21]} {dbg_instr[22]} {dbg_instr[23]} {dbg_instr[24]} {dbg_instr[25]} {dbg_instr[26]} {dbg_instr[27]} {dbg_instr[28]} {dbg_instr[29]} {dbg_instr[2]} {dbg_instr[30]} {dbg_instr[31]} {dbg_instr[3]} {dbg_instr[4]} {dbg_instr[5]} {dbg_instr[6]} {dbg_instr[7]} {dbg_instr[8]} {dbg_instr[9]}]]
create_debug_port u_ila probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila/probe2]
set_property port_width 32 [get_debug_ports u_ila/probe2]
connect_debug_port u_ila/probe2 [get_nets [list {dbg_cycles[0]} {dbg_cycles[10]} {dbg_cycles[11]} {dbg_cycles[12]} {dbg_cycles[13]} {dbg_cycles[14]} {dbg_cycles[15]} {dbg_cycles[16]} {dbg_cycles[17]} {dbg_cycles[18]} {dbg_cycles[19]} {dbg_cycles[1]} {dbg_cycles[20]} {dbg_cycles[21]} {dbg_cycles[22]} {dbg_cycles[23]} {dbg_cycles[24]} {dbg_cycles[25]} {dbg_cycles[26]} {dbg_cycles[27]} {dbg_cycles[28]} {dbg_cycles[29]} {dbg_cycles[2]} {dbg_cycles[30]} {dbg_cycles[31]} {dbg_cycles[3]} {dbg_cycles[4]} {dbg_cycles[5]} {dbg_cycles[6]} {dbg_cycles[7]} {dbg_cycles[8]} {dbg_cycles[9]}]]
create_debug_port u_ila probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila/probe3]
set_property port_width 32 [get_debug_ports u_ila/probe3]
connect_debug_port u_ila/probe3 [get_nets [list {dbg_icount[0]} {dbg_icount[10]} {dbg_icount[11]} {dbg_icount[12]} {dbg_icount[13]} {dbg_icount[14]} {dbg_icount[15]} {dbg_icount[16]} {dbg_icount[17]} {dbg_icount[18]} {dbg_icount[19]} {dbg_icount[1]} {dbg_icount[20]} {dbg_icount[21]} {dbg_icount[22]} {dbg_icount[23]} {dbg_icount[24]} {dbg_icount[25]} {dbg_icount[26]} {dbg_icount[27]} {dbg_icount[28]} {dbg_icount[29]} {dbg_icount[2]} {dbg_icount[30]} {dbg_icount[31]} {dbg_icount[3]} {dbg_icount[4]} {dbg_icount[5]} {dbg_icount[6]} {dbg_icount[7]} {dbg_icount[8]} {dbg_icount[9]}]]
create_debug_port u_ila probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila/probe4]
set_property port_width 32 [get_debug_ports u_ila/probe4]
connect_debug_port u_ila/probe4 [get_nets [list {dbg_stalls[0]} {dbg_stalls[10]} {dbg_stalls[11]} {dbg_stalls[12]} {dbg_stalls[13]} {dbg_stalls[14]} {dbg_stalls[15]} {dbg_stalls[16]} {dbg_stalls[17]} {dbg_stalls[18]} {dbg_stalls[19]} {dbg_stalls[1]} {dbg_stalls[20]} {dbg_stalls[21]} {dbg_stalls[22]} {dbg_stalls[23]} {dbg_stalls[24]} {dbg_stalls[25]} {dbg_stalls[26]} {dbg_stalls[27]} {dbg_stalls[28]} {dbg_stalls[29]} {dbg_stalls[2]} {dbg_stalls[30]} {dbg_stalls[31]} {dbg_stalls[3]} {dbg_stalls[4]} {dbg_stalls[5]} {dbg_stalls[6]} {dbg_stalls[7]} {dbg_stalls[8]} {dbg_stalls[9]}]]
create_debug_port u_ila probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila/probe5]
set_property port_width 1 [get_debug_ports u_ila/probe5]
connect_debug_port u_ila/probe5 [get_nets [list dbg_halted]]
create_debug_port u_ila probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila/probe6]
set_property port_width 1 [get_debug_ports u_ila/probe6]
connect_debug_port u_ila/probe6 [get_nets [list dbg_trap]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_IBUF_BUFG]
