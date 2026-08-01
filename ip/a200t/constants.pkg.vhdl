-- SPDX-License-Identifier: Apache-2.0

--! @file constants.pkg.vhdl
--! @brief This file contains constants for the A200T board.
--!
--! The main public API element is the `constants` package.
--! See @ref constants for more details.

library ieee;
use ieee.std_logic_1164.all;

--! @brief A200T size parameters.
--!
--! @details Use as:
--! ```vhdl
--! library a200t_constants;
--! use a200t_constants.constants;
--! -- ...
--! constant foo: positive := constants.DQS_WIDTH;
--! ```
package constants is

    --! The DQS signal bit width.
    constant DQS_WIDTH: positive := 4;
    --! The data bus bit width.
    constant DQ_WIDTH: positive := 32;
    --! The address bus bit width.
    constant A_WIDTH: positive := 32;
    --! The BA bus bit width.
    constant BA_WIDTH: positive := 3;

    --! The DDR3 address bus bit width.
    constant DDR3_A_WIDTH: positive := 15;

end package;
