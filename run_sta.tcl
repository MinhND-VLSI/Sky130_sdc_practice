set LIB_PATH "/input/sky130_fd_sc_hd__tt_025C_1v80.lib"

read_liberty $LIB_PATH
read_verilog /input/seq_adder_netlist.v
link_design seq_adder
read_sdc /input/seq_adder_10ns.sdc

report_checks -path_delay max
report_checks -path_delay min
report_tns
report_wns
