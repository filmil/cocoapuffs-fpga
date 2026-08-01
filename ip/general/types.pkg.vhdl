-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;

package types is

    --! @brief Input signals for a single SERV Write Port.
    type serv_rf_w_in_t is record
        --! Register address (6 bits for 64 registers).
        reg  : std_ulogic_vector(5 downto 0);
        --! Write enable.
        en   : std_ulogic;
        --! Parallel write data.
        data : std_ulogic_vector(31 downto 0);
    end record;

    --! @brief Input signals for a single SERV Read Port.
    type serv_rf_r_in_t is record
        --! Register address (6 bits for 64 registers).
        reg : std_ulogic_vector(5 downto 0);
    end record;

    --! @brief Output signals for a single SERV Read Port.
    type serv_rf_r_out_t is record
        --! Parallel read data.
        data : std_ulogic_vector(31 downto 0);
    end record;

    --! @brief Input signals for the SERV Register File.
    type serv_rf_in_t is record
        --! Write request from the core. Starts a write transaction.
        wreq : std_ulogic;
        --! Read request from the core. Starts a read transaction.
        rreq : std_ulogic;
        --! Write port 0.
        w0   : serv_rf_w_in_t;
        --! Write port 1.
        w1   : serv_rf_w_in_t;
        --! Read port 0.
        r0   : serv_rf_r_in_t;
        --! Read port 1.
        r1   : serv_rf_r_in_t;
    end record;

    --! @brief Output signals from the SERV Register File.
    type serv_rf_out_t is record
        --! Ready signal to core. Indicates RF is ready.
        ready : std_ulogic;
        --! Read port 0 data.
        r0    : serv_rf_r_out_t;
        --! Read port 1 data.
        r1    : serv_rf_r_out_t;
    end record;

end package;
