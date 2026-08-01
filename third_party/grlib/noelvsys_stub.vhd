-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
library gaisler;
use gaisler.uart.all;

entity noelvsys is
  generic (
    fabtech  : integer;
    memtech  : integer;
    ncpu     : integer;
    nextmst  : integer;
    nextslv  : integer;
    nextapb  : integer;
    ndbgmst  : integer;
    nintdom  : integer;
    neiid    : integer;
    cached   : integer;
    wbmask   : integer;
    busw     : integer;
    cmemconf : integer;
    rfconf   : integer;
    fpuconf  : integer;
    tcmconf  : integer;
    mulconf  : integer;
    intcconf : integer;
    disas    : integer;
    ahbtrace : integer;
    cfg      : integer;
    devid    : integer;
    nodbus   : integer;
    trace    : integer;
    scantest : integer
  );
  port (
    clk      : in  std_ulogic;
    gclk     : in  std_logic_vector(ncpu-1 downto 0);
    rstn     : in  std_ulogic;
    pwrd     : out std_logic_vector(ncpu-1 downto 0) := (others => '0');
    ahbmi    : out ahb_mst_in_type := ahbm_in_none;
    ahbmo    : in  ahb_mst_out_vector_type(ncpu + nextmst - 1 downto ncpu);
    ahbsi    : out ahb_slv_in_type := ahbs_in_none;
    ahbso    : in  ahb_slv_out_vector_type(nextslv - 1 downto 0);
    dbgmi    : out ahb_mst_in_vector_type(ndbgmst - 1 downto 0) := (others => ahbm_in_none);
    dbgmo    : in  ahb_mst_out_vector_type(ndbgmst - 1 downto 0);
    apbi     : out apb_slv_in_type := apb_slv_in_none;
    apbo     : in  apb_slv_out_vector;
    dsuen    : in  std_ulogic;
    dsubreak : in  std_ulogic;
    cpu0errn : out std_ulogic := '0';
    uarti    : in  uart_in_type;
    uarto    : out uart_out_type := (rtsn => '1', txd => '1', scaler => (others => '0'), txen => '0', flow => '0', rxen => '0', txtick => '0', rxtick => '0')
  );
end entity;

architecture stub of noelvsys is
begin
    -- Empty architecture stub
end architecture;
