<!-- SPDX-License-Identifier: Apache-2.0 -->
# Bus naming style

## VHDL

This section documents the naming conventions for the bus signals in VHDL. In
VHDL we use packages and records heavily, to group related signals into
buses.

Naming concerns are listed here:

- Buses connect submodules that are usually hierarchically ordered. We call
  these roles `host` and `peripheral` (shortened to `per`).
- We name libraries based on submodules. For example, modules defined here are
  `axi`, or `ddr3`.
- Bus signals are grouped into VDHL records. The record type names are suffixed
  by `_type`, to help distinguishing type names from signal and variable names.
- Signals are named based on which submodule they are driven from. A bus signal
  set driven from the host will be named like `host_type`.
- Modern buses are divided into multiple channels.  We define a type per each
  driver and channel name combination, to ensure that we can represent either
  direction.

### Examples

#### AXI bus

For the AXI bus, we define a library called `axi`.

The AXI bus connects two submodule types, we call them host and peripheral. We
therefore define two packages, `host` and `per`.

We define another package under the `axi` library, called `types`, which contains
the width configurations for the bus, to support different AXI bus widths.  This
pattern repeats in other bus definitions, such as `ddr3`.

```vhdl
package types is
type widths_type is record
    id: positive;
    len: positive;
    burst: positive;
    strb: positive;
    resp:positive;
end record;
constant WIDTHS: widths_type := (id => 4, len => 8, burst => 2, strb => 4, resp => 2);
end package;
```
We can use the constant `axi.types.WIDTHS` when we need to refer to any bus widths.

We define a `host` package, and every channel and every channel of the bus. So we
define one `<x>_type` for every bus channel `<x>` defined by the AXI spec.

```vhdl
--! Defines the AXI host bus signals.
package host is
type aw_type is record
  -- etc.
end record;
type w_type is record
  -- etc.
end record;
-- etc.
end package;
```

In the end, we group all the channels into a `bus_type`:

```vhdl
type bus_type is record
    aw: aw_type;
    w: w_type;
    b: b_type;
    ar: ar_type;
    r: r_type;
end record;
```

This allows compact declarations such as shown below. It declares a signal with
all AXI channels supported by the host side of the AXI collaboration.

```
library axi;
signal from_host: axi.host.bus_type;
```

#### DDR3 bus

The DDR3 bus is perhaps more interesting, since it includes multiple
interfaces.  The configuration type is:

```vhdl
package cfg is
type widths_type is record
    cfg: positive;
end record;
constant WIDTHS: widths_type := ( cfg => 32);
type in_type is record
    valid: std_ulogic;
    config: std_ulogic_vector(WIDTHS.cfg-1 downto 0);
end record;
end package;
```
This similarly uses `ddr3.cfg.WIDTHS` to declare bus widths.

The PHY ("ddr3-to-phy-interface") is more interesting because it comes in
multiple bit widths.

```vhdl
package phy is
type width_type is record
    addr: positive;
    ba: positive;
    dm: positive;
    dq: positive;
    dqs: positive;
end record;
-- etc.
end package;
--! Bus widths for a 32-bit bus type.
constant WIDTH_32B: width_type := (addr => 14, ba => 3, dm => 2, dq => 16, dqs => 2);
--! Bus widths for a 16-bit bus type.
constant WIDTH_16B: width_type := (addr => 14, ba => 3, dm => 2, dq => 16, dqs => 2);
```

This allows us to define `host_type` and `inout_type` in terms of  *unconstrained* logic
vectors.

```vhdl
type host_type is record
    ck_p, ck_n, cke, reset_n, ras_n, cas_n, we_n, cs_n: std_ulogic;
    ba: std_ulogic_vector;
    addr: std_ulogic_vector;
    odt: std_ulogic;
    dm: std_ulogic_vector;
end record;
```

Unconstrained vectors typically can not be used directly, so we also provide a
*constructor* function that allows us to create constrained types from predefined
`width_type`s.

```vhdl
function new_host_type(constant width: width_type) return host_type;
```

This allows us to do the following, constraining `ddr3_sig` to be a 32-bit
host-side signal record.

```vhdl
library ddr3;
-- etc.
signal ddr3_sig: ddr3.phy.host_type := ddr3.phy.new_host_type(ddr3.phy.WIDTH_32B);
```
Or, you can use a constrained subtype directly.
```vhdl
library ddr3;
-- etc.
signal ddr3_sig: ddr3.phy32.host_type;
```

This pattern is repeated for other types where this is useful. It would have
been easier if VHDL had generic types, but it does not. So we're kind of
emulating them in this case.
