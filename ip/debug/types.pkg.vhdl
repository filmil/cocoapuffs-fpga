library ieee;
use ieee.std_logic_1164.all;

package debug is

constant darray_size: natural := 32;
subtype darray is std_ulogic_vector(darray_size-1 downto 0);

end package;
