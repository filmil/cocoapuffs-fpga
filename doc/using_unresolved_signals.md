<!-- SPDX-License-Identifier: Apache-2.0 -->
# Using unresolved signals

## `std_ulogic`

Signals that do not need to be connected to lines with multiple drivers should be
declared as "ulogic" as:

```vhdl
library ieee;
use ieee.std_logic_1164.all;
signal one_bit: std_ulogic;
signal a_vector: std_ulogic_vector;
```

This is useful because accidentally driving the same wire by two different
signals will be a compilation error.

## `std_logic`

The inout signals are rare (impossible?) inside an FPGA, but are used when
interfacing with external chips such as DDR3 memory modules. These *must* be
`std_logic` to allow them to coexist on a tri-state bus with potential other
drivers.

```vhdl
library ieee;
use ieee.std_logic_1164.all;
signal one_bit_multiple_drivers_multiple_drivers_allowed: std_logic;
signal a_vector_multiple_drivers_allowed: std_logic_vector;
```
