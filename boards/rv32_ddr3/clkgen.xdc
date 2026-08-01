# Write down the clocks and relationships of the clock generator.

create_generated_clock  \
 -source [get_ports sys_clk_p] \
 -multiply_by 1 \
 [get_pins clkgen0/clock_generator/CLKIN1]

create_generated_clock \
 -source [get_pins clkgen0/clock_generator/CLKIN1] \
 -divide_by 2 [get_pins clkgen0/clock_generator/CLKOUT0]

create_generated_clock \
 -source [get_pins clkgen0/clock_generator/CLKIN1] \
 -multiply_by 2 [get_pins clkgen0/clock_generator/CLKOUT1]

create_generated_clock \
 -source [get_pins clkgen0/clock_generator/CLKIN1] \
 -multiply_by 1 \
 [get_pins clkgen0/clock_generator/CLKOUT2]

create_generated_clock \
 -source [get_pins clkgen0/clock_generator/CLKIN1] \
 -edges {1 2 3} \
 -edge_shift {1.25 1.25 1.25}  \
 [get_pins clkgen0/clock_generator/CLKOUT3]

