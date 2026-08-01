-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library wb;
use wb.signals.all;

entity rdt_mux_test is
    generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture sim of rdt_mux_test is
    constant num_inputs : positive := 4;
    signal rst : std_ulogic := '1';
    signal inputs : rdt_mux_in_t(0 to num_inputs-1) := (others => i_wb_new);
    signal output : i_wb;

begin
    dut: entity wb.rdt_mux
        port map (
            rst => rst,
            input => inputs,
            output => output
        );

    main: process
    begin
        test_runner_setup(runner, runner_cfg);

        while is_active(runner) loop
            if run("test_reset") then
                info("Testing reset behavior");
                rst <= '1';
                inputs(0) <= (ack => '1', rdt => x"12345678");
                wait for 1 ns;
                check_equal(output.ack, '0', "Output ack should be 0 during reset");
                check_equal(output.rdt, std_logic_vector'(x"00000000"), "Output rdt should be 0 during reset");

            elsif run("test_mux_behavior") then
                info("Testing mux behavior");
                rst <= '0';
                
                info("No input acked");
                inputs <= (others => i_wb_new);
                wait for 1 ns;
                check_equal(output.ack, '0', "Output ack should be 0 when no input is acked");

                info("Input 0 acked");
                inputs(0) <= (ack => '1', rdt => x"AAAAAAAA");
                wait for 1 ns;
                check_equal(output.ack, '1', "Output ack mismatch for input 0");
                check_equal(output.rdt, std_logic_vector'(x"AAAAAAAA"), "Output rdt mismatch for input 0");

                info("Input 2 acked");
                inputs(0) <= i_wb_new;
                inputs(2) <= (ack => '1', rdt => x"CCCCCCCC");
                wait for 1 ns;
                check_equal(output.ack, '1', "Output ack mismatch for input 2");
                check_equal(output.rdt, std_logic_vector'(x"CCCCCCCC"), "Output rdt mismatch for input 2");

                info("Multiple inputs acked (priority test)");
                -- The implementation uses a loop from high to low, so higher index has priority?
                -- for i in input'high downto input'low loop
                --   if input(i).ack = '1' then
                --     output_v := (rdt => input(i).rdt, ack => input(i).ack);
                --   end if;
                -- end loop;
                -- Wait, if it loops from high to low, and overwrites, then the LAST one (low index) has priority!
                -- No, if it loops from high to low, and overwrites, the one at index 0 will be the final value.
                inputs(1) <= (ack => '1', rdt => x"BBBBBBBB");
                inputs(2) <= (ack => '1', rdt => x"CCCCCCCC");
                wait for 1 ns;
                check_equal(output.rdt, std_logic_vector'(x"BBBBBBBB"), "Priority test failed: index 1 should win over 2");
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
