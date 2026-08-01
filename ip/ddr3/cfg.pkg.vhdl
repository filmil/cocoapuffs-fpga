-- SPDX-License-Identifier: Apache-2.0

--! @file cfg.pkg.vhdl
--! @brief DDR3 configuration package.
--!
--! See @ref cfg for more details.
library ieee;
use ieee.std_logic_1164.all;

--! @brief DDR3 configuration package.
package cfg is

--! Configuration type for the package `cfg`.
type widths_type is record
    cfg: positive;
end record;

--! Field widths declaration.
constant WIDTHS: widths_type := ( cfg => 32);

--! Input configuration record.
type in_type is record
    --! Asserted high when the configuration is valid.
    valid: std_ulogic;
    --! The configuration vector.
    config: std_ulogic_vector(WIDTHS.cfg-1 downto 0);
end record;

end package;
