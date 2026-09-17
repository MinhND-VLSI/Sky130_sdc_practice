set sdc_version 2.1
set_units -time ns -capacitance pF

create_clock -name clk -period 2 [get_ports clk]
set_clock_uncertainty 0.15 [get_clocks clk]
set_clock_transition 0.1 [get_clocks clk]

set_input_delay -clock clk -max 3 [get_ports {data_in en}]
set_input_delay -clock clk -min 1 [get_ports {data_in en}]
set_output_delay -clock clk -max 3 [get_ports {data_out valid_out}]
set_output_delay -clock clk -min 1 [get_ports {data_out valid_out}]

set_false_path -from [get_ports rst_n]

set_max_fanout 8 [current_design]
set_max_transition 1.5 [current_design]