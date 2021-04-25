

create_clock -name board_clk -period 10.000 -waveform {0.000 5.000} -add [get_ports clk]

set_property PACKAGE_PIN M22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {clk_IBUF}]

set_property PACKAGE_PIN H7 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

set_property PACKAGE_PIN J8 [get_ports clear]
set_property IOSTANDARD LVCMOS33 [get_ports clear]

set_property PACKAGE_PIN E3 [get_ports rs232_tx_data_o]
set_property IOSTANDARD LVCMOS33 [get_ports rs232_tx_data_o]
set_property PACKAGE_PIN F3 [get_ports rs232_rx_data_i]
set_property IOSTANDARD LVCMOS33 [get_ports rs232_rx_data_i]

set_property BITSTREAM.CONFIG.UNUSEDPIN Pulldown [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]