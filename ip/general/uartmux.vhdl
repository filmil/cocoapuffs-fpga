library ieee;
use ieee.std_logic_1164.all;

--! @brief Multiplexes serial lines.
--!
--! One pair of lines goes in, multiple lines are connected to transmitter.
entity uartmux is
    generic (
        num_ports: positive := 1
    );
    port (

        remote_rx: in std_logic
        ; remote_tx: out std_logic

        ; local_rx: out std_logic_vector(num_ports-1 downto 0)
        ; local_tx: in std_logic_vector(num_ports-1 downto 0)
    );
end entity;

architecture rtl of uartmux is
begin

    comb: process(remote_rx, local_tx)
        variable tx, rx: std_logic;

    begin
        tx := '1';
        for i in 0 to num_ports-1 loop
            tx := tx and local_tx(i);
        end loop;
        remote_tx <= tx;

        rx := remote_rx;
        for i in 0 to num_ports-1 loop
            local_rx(i) <= rx;
        end loop;
    end process;
end architecture;

