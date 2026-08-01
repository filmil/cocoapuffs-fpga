library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

library wb;

entity wblite_mem is
    generic(
        base_address: std_ulogic_vector(wb.types.WIDTHS_32B.adr-1 downto 0) := (
            others => '0');
        mem_size_log2: natural := 1; -- 2^1 = 2
        logger: logger_t := get_logger("unnamed.wblite_mem");
    );
    port(
        clk, reset: in std_ulogic;
        --! Input from the host.
        host: in wb.host.bus_type;
        --! Output from this peripheral.
        per: out wb.per.bus_type
    );
end entity;

architecture sim of wblite_mem is

    signal write: boolean;
    signal regi, rego: std_ulogic_vector(31 downto 0);
    signal index: natural;

    type mem_t is array(0 to 2**mem_size_log2-1) of std_ulogic_vector(
        wb.types.WIDTHS_32B.dat-1 downto 0
    );

    constant mem_zero: mem_t := (others => (others => '0'));

    signal mem: mem_t := mem_zero;

    --! Masks the bytes of `val` based on bits of `sel`. Each bit of `sel` is
    --! a lane selector.
    function masked_value(val: std_ulogic_vector; sel: std_ulogic_vector)
        return std_ulogic_vector is
        variable mask: std_ulogic_vector(val'range) := (others => '0');
    begin
        for i in sel'low to sel'high loop
            mask((i + 1) * 8 - 1 downto i * 8) := (others => sel(i));
        end loop;
        return val and mask;
    end function;

begin
    regi <= masked_value(mem(index), host.sel);

    decoder0: entity wb.mmreg_decoder
    generic map(
        base_address => base_address,
        reg_bit_count => mem_size_log2
    )
    port map(
        clk => clk
        , reset => reset
        , regi => regi
        , rego => rego
        , indexo => index
        , wbi => host
        , wbo => per
        , write => write
    );

    seq: process(clk) is
    begin
        if rising_edge(clk) then
            if reset = '1' then
                mem <= mem_zero;
                log(logger, "reset");
            else
                if write then
                    mem(index) <= masked_value(rego, host.sel);
                    log(logger, "write mem["
                        & to_string(4*index) & "] <= 0x" & to_hstring(rego));
                end if;
            end if;
        end if;
    end process;
end architecture;

