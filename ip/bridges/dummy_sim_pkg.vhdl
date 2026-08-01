-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;

package sim is
    type device_table_t is array (integer range <>) of string(1 to 32);
    type device_entry_t is record
        device_table : device_table_t(0 to 0);
    end record;
    type device_array_t is array (integer range <>) of device_entry_t;

    constant iptable : device_array_t(0 to 255) := (
        others => (device_table => (others => "Unknown Device                  "))
    );

    procedure call_subtest(vendorid, deviceid, subtest : integer);

    -- For aximem.vhd
    type ramback_in_type is record
        addr: std_logic_vector(31 downto 0);
        wr: std_logic_vector(15 downto 0);
        din: std_logic_vector(127 downto 0);
        clear,reload,dbgdump: std_logic;
    end record;

    constant ramback_in_none: ramback_in_type :=
        ((others => '0'), (others => '0'), (others => '0'), '0', '0', '0');

    type ramback_out_type is record
        addr: std_logic_vector(31 downto 0);
        dout: std_logic_vector(127 downto 0);
        cmdack: std_logic;
    end record;

    constant ramback_out_none: ramback_out_type := ((others => '0'), (others => '0'), '0');

    type ramback_in_array is array(natural range <>) of ramback_in_type;
    type ramback_out_array is array(natural range <>) of ramback_out_type;

    -- For axixmem.vhd
    type aximem_error_type is record
        id : integer;
        dstype : std_logic;
        addr : std_logic_vector(31 downto 0);
        mask : std_logic_vector(31 downto 0);
        valid : std_logic;
        enabled : std_logic;
        entry_strobe : std_logic;
    end record;

    type aximem_rac_type is record
        wait_for_valid : std_logic;
        entry_strobe : std_logic;
    end record;

    type aximem_wac_type is record
        wait_for_valid : std_logic;
        entry_strobe : std_logic;
    end record;

    type aximem_wdc_type is record
        wait_for_valid : std_logic;
        entry_strobe : std_logic;
    end record;

    type aximem_conf_type is record
        err : aximem_error_type;
        wac : aximem_wac_type;
        wdc : aximem_wdc_type;
        rac : aximem_rac_type;
    end record;

    constant aximem_error_type_def : aximem_error_type := (
        id => 0,
        dstype => '0',
        addr => (others => '0'),
        mask => (others => '0'),
        valid => '0',
        enabled => '0',
        entry_strobe => '0'
    );

    constant aximem_rac_type_def : aximem_rac_type := (
        wait_for_valid => '0',
        entry_strobe => '0'
    );

    constant aximem_wac_type_def : aximem_wac_type := (
        wait_for_valid => '0',
        entry_strobe => '0'
    );

    constant aximem_wdc_type_def : aximem_wdc_type := (
        wait_for_valid => '0',
        entry_strobe => '0'
    );

    constant aximem_conf_type_def : aximem_conf_type := (
        err => aximem_error_type_def,
        wac => aximem_wac_type_def,
        wdc => aximem_wdc_type_def,
        rac => aximem_rac_type_def
    );

    component htif_sim is
      generic (
        dbg           : boolean := false;
        dev_cmd_width : integer := 8;
        data_width    : integer := 64;
        addr_width    : integer := 32;
        tohost_addr   : std_logic_vector(63 downto 0);
        fromhost_addr : std_logic_vector(63 downto 0)
      );
      port (
        clk   : in std_logic;
        addr  : in std_logic_vector(addr_width - 1 downto 0);
        data  : in std_logic_vector(data_width - 1 downto 0);
        size  : in std_logic_vector(2 downto 0);
        valid : in std_logic;
        rw    : in std_logic;
        id    : in std_logic_vector(3 downto 0)
      );
    end component htif_sim;

end package;

package body sim is
    procedure call_subtest(vendorid, deviceid, subtest : integer) is
    begin
        null;
    end procedure;
end package body;
