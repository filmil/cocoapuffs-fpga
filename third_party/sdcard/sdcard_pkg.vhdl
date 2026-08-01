-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;

--! @file sdcard_pkg.vhdl
--! @brief Definitions for the SD card module interfaces.

--! @brief SD card definitions and types.
package sdcard_pkg is

    --! @brief SPI host-to-device (master-to-slave) signals.
    --! Signals driven by the SPI master (host) and received by the SD card.
    type spi_h2d_t is record
        cs_n : std_logic; --! Chip select (active low)
        sck  : std_logic; --! Serial clock
        mosi : std_logic; --! Master out slave in
    end record;

    --! @brief SPI device-to-host (slave-to-master) signals.
    --! Signals driven by the SD card and received by the SPI master (host).
    type spi_d2h_t is record
        miso : std_logic; --! Master in slave out
    end record;

end package sdcard_pkg;
