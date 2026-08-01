-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library wb;

entity cyc_demux_test is
    generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture sim of cyc_demux_test is
    constant demux_width : positive := 2;
    signal cyc : std_ulogic := '0';
    signal sel : std_ulogic_vector(demux_width-1 downto 0) := (others => '0');
    signal cyc_out : std_ulogic_vector(2**demux_width-1 downto 0);

begin
    dut: entity wb.cyc_demux
        generic map (
            demux_width => demux_width
        )
        port map (
            cyc => cyc,
            sel => sel,
            cyc_out => cyc_out
        );

    main: process
    begin
        test_runner_setup(runner, runner_cfg);

        while is_active(runner) loop
            if run("test_demux_behavior") then
                info("Testing demux with cyc='0'");
                cyc <= '0';
                for i in 0 to 2**demux_width-1 loop
                    sel <= std_ulogic_vector(to_unsigned(i, demux_width));
                    wait for 1 ns;
                    check_equal(cyc_out, std_ulogic_vector'(x"0"), "All outputs should be 0 when cyc is 0");
                end loop;

                info("Testing demux with cyc='1'");
                cyc <= '1';
                for i in 0 to 2**demux_width-1 loop
                    sel <= std_ulogic_vector(to_unsigned(i, demux_width));
                    wait for 1 ns;
                    for j in 0 to 2**demux_width-1 loop
                        if i = j then
                            check_equal(cyc_out(j), '1', "Output " & integer'image(j) & " should be 1");
                        else
                            check_equal(cyc_out(j), '0', "Output " & integer'image(j) & " should be 0");
                        end if;
                    end loop;
                end loop;
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

    watchdog: process
    begin
        wait for 1 us;
        assert false report "Watchdog timeout" severity failure;
    end process;

end architecture;
