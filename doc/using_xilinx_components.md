<!-- SPDX-License-Identifier: Apache-2.0 -->
# Using Xilinx components

Noting down how to use Xilinx components in a VHDL entity.

Add the dependency in `BUILD.bazel`:

```python
# ...
deps = [
  "//third-party/xilinx:unisim",
],
```

You can then instantiate as follows. Note that no
`component` declaration is needed. Also there is no need to
capitalize `IBUF`, but this is somewhat of a convention for
vendor primitives.

```vhdl
library ieee;
use ieee.std_logic_1164;
library unisim;
use unisim.vcomponents.all;

-- etc.
entity ent is
  -- etc.
end entity;
architecture example of ent is
    signal some_input, some_output: std_logic;
begin
    ibuf_in: IBUF -- This is from `unisim.vcomponents.*`
    port map (
        I => some_input,
        O => some_output
    );
end entity;
```

