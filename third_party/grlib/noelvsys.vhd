------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
-----------------------------------------------------------------------------
-- Entity:      noelvsys
-- File:        noelvsys.vhd
-- Author:      Nils Wessman, Cobham Gaisler
-- Description: NOEL-V processor system (CPUs,FPUs,DM,ACLINT,IMSIC,APLIC,UART,AMBA)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.amba.all;
use grlib.config.all;
use grlib.config_types.all;
use grlib.devices.all;
use grlib.stdlib.log2x;
use grlib.stdlib.conv_integer;
use grlib.stdlib.conv_std_logic;
use grlib.stdlib.notx;
-- pragma translate_off
use grlib.stdlib.tost;
use grlib.stdlib.print;
-- pragma translate_on
library gaisler;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.noelv.all;
use gaisler.plic.all;
use gaisler.aplic.all;
use gaisler.misc.grgpreg;
-- pragma translate_off
use gaisler.sim.htif_sim;
-- pragma translate_on


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
    -- Power down mode
    pwrd     : out std_logic_vector(ncpu-1 downto 0);
    -- AHB bus interface for other masters (DMA units)
    ahbmi    : out ahb_mst_in_type;
    ahbmo    : in  ahb_mst_out_vector_type(ncpu + nextmst - 1 downto ncpu);
    -- AHB bus interface for slaves (memory controllers, etc)
    ahbsi    : out ahb_slv_in_type;
    ahbso    : in  ahb_slv_out_vector_type(nextslv - 1 downto 0);
    -- AHB master interface for debug links
    dbgmi    : out ahb_mst_in_vector_type(ndbgmst - 1 downto 0);
    dbgmo    : in  ahb_mst_out_vector_type(ndbgmst - 1 downto 0);
    -- APB interface for external APB slaves
    apbi     : out apb_slv_in_type;
    apbo     : in  apb_slv_out_vector;
    -- Bootstrap signals
    dsuen    : in  std_ulogic;
    dsubreak : in  std_ulogic;
    cpu0errn : out std_ulogic;
    -- UART connection
    uarti    : in  uart_in_type;
    uarto    : out uart_out_type;
    -- Perf counter
    cnt      : out nv_counter_out_vector(ncpu - 1 downto 0);
    -- E-trace sink interface
    etso     : out nv_etrace_sink_out_vector(ncpu - 1 downto 0);
    etsi     : in  nv_etrace_sink_in_vector(ncpu - 1 downto 0) := (others => nv_etrace_sink_in_none);
    -- DFT support
    testen   : in  std_ulogic := '0';
    testrst  : in  std_ulogic := '1';
    scanen   : in  std_ulogic := '0';
    testoen  : in  std_ulogic := '1';
    testsig  : in  std_logic_vector(1 + GRLIB_CONFIG_ARRAY(grlib_techmap_testin_extra) downto 0) := (others => '0')

    );
end;

architecture hier of noelvsys is


  -- AIA configuration functions -------------------------------------

  function no_x(v        : std_logic_vector;
                all_zero : boolean := false) return std_logic_vector is
  begin
    return v;
  end;
  function no_x(v        : std_ulogic;
                all_zero : boolean := false) return std_ulogic is
  begin
    return v;
  end;
  function config_interrupts(cfg : integer; conf : integer; support : integer) return integer is
    variable cfg_typ  : integer;
    variable cfg_lite : integer;
    variable config   : integer := support * conf;
  begin
    cfg_typ  := (cfg / 256)  mod 16;
    cfg_lite := (cfg / 128)  mod 2;

    -- If core is configured as HP or GP AIA is enabled
    if cfg_typ /= 0  then
      if not(cfg_typ = 2 or cfg_typ = 15 or
             (cfg_typ = 3 and cfg_lite = 1)) then
        return config;
      else
        return 0;
      end if;
    else
      -- Old configuration
      if not(cfg = 3 or cfg = 4 or cfg = 5 or cfg = 6) then
        return config;
      else
        return 0;
      end if;
    end if;
  end function;

  function set_IMSIC_addr(HADDR : integer) return std_logic_vector is
    variable IMSIC_addr : std_logic_vector(31 downto 0);
  begin
    IMSIC_addr := std_logic_vector(to_unsigned(HADDR, 12)) & x"00000";
    return IMSIC_addr;
  end function;


  function calc_sbase(
    base      : std_logic_vector(31 downto 0);
    ncpu      : integer;
    groups    : integer;
    H_EN      : integer range 0 to 1;
    nvcpubits : integer)                         -- guest hart
    return std_logic_vector is
      variable addr      : std_logic_vector(31 downto 0);
      variable ncpubits  : integer;
      variable groupbits : integer;
      variable bitnumber : integer;
  begin
    if groups = 0 then
      ncpubits  := log2x(ncpu);
      bitnumber := ncpubits + nvcpubits * H_EN + 12;
    else
      ncpubits  := log2x(ncpu / groups);
      groupbits := log2x(groups);
      bitnumber := ncpubits + nvcpubits * H_EN + groupbits + 12;
    end if;
    addr := base;
    addr(bitnumber) := '1';
    return addr;
  end function;

  function calc_ncpubits(
    ncpu      : integer;
    groups    : integer)
    return integer is
  begin
    -- The number of bits needed to reference the harts
    -- is different if cpus are grouped
    if groups = 0 then
      return log2x(ncpu);
    else
      return log2x(ncpu / groups);
    end if;
  end function;


  constant doms_per_branch : integer := 2;
  constant branches        : integer := ncpu;
  constant ndoms           : integer := doms_per_branch * branches + 1;

  type aplic_harts_config_type is array (0 to ndoms - 1) of std_logic_vector(0 to ncpu - 1);

  function set_aplic_dom_harts_config(
    ncpu : integer;
    ndom : integer
  ) return aplic_harts_config_type is
    variable out_config  : aplic_harts_config_type;
    variable cpu_per_dom : integer := ncpu / ndom;
  begin
    -- Default configuration
    -- Assign all CPUs to root domain and m- and s-mode domain in first branch.
    for i in 0 to ndom-1 loop
      out_config(i) := (others => '0');
    end loop;
    out_config(0) := (others => '1');   -- root domain
    if ndom >= 2 then
      out_config(1) := (others => '1'); -- m-mode domain
    end if;
    if ndom >= 3 then
      out_config(2) := (others => '1'); -- s-mode domain
    end if;
    return out_config;
  end function;


  function config_domain_harts(in_config_arr : aplic_harts_config_type) return preset_active_harts_type is
    variable out_config_arr : preset_active_harts_type := (others => (others => '0'));
  begin
    for i in in_config_arr'range loop
      out_config_arr(i)(ncpu-1 downto 0) := in_config_arr(i);
    end loop;
    return out_config_arr;
  end function;

  -- Helper functions to shuffle PnP entries

  function replace_hindex(x : ahb_slv_out_type; hindex : integer) return ahb_slv_out_type is
    variable r : ahb_slv_out_type := x;
  begin
    r.hindex := hindex;

    return r;
  end replace_hindex;

  function replace_pindex(x : apb_slv_out_type; pindex : integer) return apb_slv_out_type is
    variable r : apb_slv_out_type := x;
  begin
    r.pindex := pindex;

    return r;
  end replace_pindex;

  function shift_psel(x: apb_slv_in_type; nshift: integer; nslaves: integer) return apb_slv_in_type is
    variable r : apb_slv_in_type := x;
  begin
    for i in 0 to nslaves-1 loop
      r.psel(i) := x.psel((nslaves + i + nshift) mod nslaves);
    end loop;

    return r;
  end shift_psel;

  function shift_hsel(x: ahb_slv_in_type; nshift: integer; nslaves: integer) return ahb_slv_in_type is
    variable r : ahb_slv_in_type := x;
  begin
    for i in 0 to nslaves-1 loop
      r.hsel(i) := x.hsel((nslaves + i + nshift) mod nslaves);
    end loop;

    return r;
  end shift_hsel;

  ----------------------------------------------------------------

  signal cpumi     : ahb_mst_in_type;
  signal cpumo     : ahb_mst_out_vector;
  signal cpusi     : ahb_slv_in_type;
  signal cpusix    : ahb_slv_in_type;
  signal cpuso     : ahb_slv_out_vector;
  signal irqi      : nv_irq_in_vector(0 to ncpu - 1);
  signal irqo      : nv_irq_out_vector(0 to ncpu - 1);
  signal aplic_meip: std_logic_vector(0 to ncpu - 1);
  signal aplic_seip: std_logic_vector(0 to ncpu - 1);
  signal imsic_ack : std_logic_vector(0 to ncpu - 1);
  signal imsic_irq : imsic_irq_vector(0 to ncpu - 1);
  signal dbgi      : nv_debug_in_vector(0 to ncpu - 1);
  signal dbgo      : nv_debug_out_vector(0 to ncpu - 1);
  signal dsui      : nv_dm_in_type;
  signal dsuo      : nv_dm_out_type;
  signal cpuapbi   : apb_slv_in_type;
  signal cpuapbix  : apb_slv_in_type;
  signal cpuapbo   : apb_slv_out_vector;
  signal gpti      : gptimer_in_type;
  signal gpto      : gptimer_out_type;
  signal tstop     : std_ulogic;
  signal xuarto    : uart_out_type;

  -- PLIC/IMSIC => CLINT
  signal eip      : nv_irq_in_vector(0 to ncpu - 1);
  signal old_eip  : nv_irq_in_vector(0 to ncpu-1);
  signal plic_eip : std_logic_vector(ncpu * 4 - 1 downto 0);
  -- Real Time Clock
  signal rtc      : std_ulogic := '0';

  -- Trace
  signal tpo      : nv_full_trace_vector(ncpu - 1 downto 0);
  signal eto      : nv_etrace_vector(ncpu - 1 downto 0);

  signal apbo_uart, apbo_gptime, apbo_etrace, apbo_iommu : apb_slv_out_type;
  signal ahbso_apbctrl : ahb_slv_out_type;

  constant preset_active_harts_default : preset_active_harts_type := (others => (others => '0'));


  constant DUAL_PLIC : integer := conv_integer(conv_std_logic(AIA_SUPPORT*intcconf >= 2));

  -- AHB master index
  constant APLIC_HMINDEX  : integer := ncpu + nextmst;
  constant AHBB_HMINDEX   : integer := ncpu + nextmst + 1;
  -- AHB slave index
  constant APBC_HINDEX    : integer := nextslv;
  constant ACLINT_HINDEX  : integer := nextslv + 1;
  constant IMSIC_HINDEX   : integer := nextslv + 2;
  constant PLIC_HINDEX    : integer := nextslv + 3;
  constant APLIC_HSINDEX  : integer := nextslv + 3+DUAL_PLIC;
  constant DM_HINDEX      : integer := nextslv + 4+DUAL_PLIC; -- Used for PnP replacement
  -- AHB slave address
  constant AHBC_IOADDR    : integer := 16#FFF#; --16#FFE# + nodbus;
  constant ACLINT_HADDR   : integer := 16#E00#;
  constant ACLINT_HMASK   : integer := 16#FFF#;
  constant IMSIC_HADDR    : integer := 16#A00#;
  constant APLIC_HADDR    : integer := 16#FC0#;
  constant PLIC_HADDR     : integer := 16#F80#;
  constant PLIC_HMASK     : integer := 16#FC0#;
  constant DM_HADDR       : integer := 16#FE0#;
  constant DM_HMASK       : integer := 16#FF0#;
  constant AHBT_IOADDR    : integer := 16#000#;
  constant AHBT_IOMASK    : integer := 16#E00#;
  constant APBC_HADDR     : integer := 16#FF9#;
  constant APBC_HMASK     : integer := 16#FFF#;
  -- APB slave index
  constant APBUART_PINDEX : integer := nextapb + 0;
  constant GPTIME_PINDEX  : integer := nextapb + 1;
  constant ETRACE_PINDEX  : integer := nextapb + 2;
  -- APB slave address
  constant APBUART_PADDR  : integer := 16#000#;
  constant APBUART_PMASK  : integer := 16#FFF#;
  constant GPTIME_PADDR   : integer := 16#080#;
  constant GPTIME_PMASK   : integer := 16#FFF#;
  constant ETRACE_PADDR   : integer := 16#010#;
  constant ETRACE_PMASK   : integer := 16#FF0#;
  -- IRQ
  constant APBUART_PIRQ   : integer := 1;
  constant GPTIME_PIRQ    : integer := 2; -- , 3
  --constant GPTIME_PIRQ2   : integer := 3;
  constant ETRACE_PIRQ    : integer := 4;
  constant WATCHDOG_HIRQ1 : integer := 1;
  constant WATCHDOG_HIRQ2 : integer := 2;

  -- UART 16550
  constant UART16550 : integer := 0;  -- 0 = Gaisler apbuart, 1 = 16550

  -- IMSIC
  constant AIA_en  : integer := config_interrupts(cfg, intcconf, AIA_SUPPORT);
  -- If AIA is enabled, then the core configuration includes the
  -- supervisor mode and the hypervisor extnesion
  constant H_EN : integer := conv_integer(conv_std_logic(AIA_en /= 0));
  constant S_EN : integer := conv_integer(conv_std_logic(AIA_en /= 0));

  constant nintid  : nidentities_vector(0 to ncpu - 1)          := (others => neiid);
  constant gnintid : nidentities_vector(0 to ncpu * GEILEN - 1) := (others => neiid);

  -- APLIC
  constant groups   : integer := 0; -- In the future could be part of the system configuration
  constant IMSIC_BADDR : std_logic_vector(31 downto 0) := set_IMSIC_addr(IMSIC_HADDR);

  -- 1 core:
  constant aplic_domains_harts : aplic_harts_config_type := set_aplic_dom_harts_config(ncpu, ndoms);

  --
  constant ncpubits    : integer := calc_ncpubits(ncpu, groups);
  constant nvcpubits   : integer := log2x(GEILEN + 1);
  constant groupbits   : integer := log2x(groups);
  --
  constant mbase_PPN : std_logic_vector(31 downto 0)  := x"000" & IMSIC_BADDR(31 downto 12); -- base_ppn is internally shifted 12 bits to the left
  constant sbase_PPN : std_logic_vector(31 downto 0)  := x"000" & calc_sbase(IMSIC_BADDR, ncpu, groups, H_EN, nvcpubits)(31 downto 12);
  constant mLHXS     : integer                        := 0;                           -- Machine Low Hart Index Shift = C - 12 (see specs)
  constant sLHXS     : integer                        := nvcpubits * H_EN;            -- Supervisor Low Hart Index Shift = D - 12 (see specs)
  constant HHXS      : integer                        := ncpubits + nvcpubits * H_EN - 12;  -- High Hart Index Shift = E - 24 (see specs)
  constant LHXW      : integer                        := ncpubits;                    -- Low Hart Index Width = k (see specs)
  constant HHXW      : integer                        := groupbits;                   -- High Hart Index Width = j (see specs)

begin

  ----------------------------------------------------------------------------
  -- AMBA bus fabric
  ----------------------------------------------------------------------------
  ac0: ahbctrl
    generic map (
      devid    => devid,
      ioaddr   => AHBC_IOADDR,
      rrobin   => 1,
      split    => 1,
      debug    => 0,
      nahbm    => ncpu + nextmst + 2,
      nahbs    => nextslv + 4 + DUAL_PLIC,
      fpnpen   => 1,
      shadow   => 1,
      ahbtrace => ahbtrace,
      ahbendian => 1
      )
    port map (
      rst  => rstn,
      clk  => clk,
      msti => cpumi,
      msto => cpumo,
      slvi => cpusi,
      slvo => cpuso,
      testen  => testen,
      testrst => testrst,
      scanen  => scanen,
      testoen => testoen,
      testsig => testsig
      );

  ahbmi <= cpumi;
  cpumo(ncpu + nextmst - 1 downto ncpu) <= ahbmo;
  cpumo(cpumo'high downto ncpu + nextmst + 1 + 1) <= (others => ahbm_none);

  -- Shift up any external AHB slaves to fit 1 internal one:
  -- apbctrl
  ahbsi.haddr <= cpusi.haddr;
  ahbsi.hwrite <= cpusi.hwrite;
  ahbsi.htrans <= cpusi.htrans;
  ahbsi.hsize <= cpusi.hsize;
  ahbsi.hburst <= cpusi.hburst;
  ahbsi.hprot <= cpusi.hprot;
  ahbsi.hwdata <= cpusi.hwdata;
  ahbsi.hmastlock <= cpusi.hmastlock;
  ahbsi.hready <= cpusi.hready;
  ahbsi.hsel(0 to nextslv - 1) <= cpusi.hsel(0 to nextslv - 1);
  ahbsi.hsel(nextslv to 15) <= (others => '0');

  cpusix.haddr <= cpusi.haddr;
  cpusix.hwrite <= cpusi.hwrite;
  cpusix.htrans <= cpusi.htrans;
  cpusix.hsize <= cpusi.hsize;
  cpusix.hburst <= cpusi.hburst;
  cpusix.hprot <= cpusi.hprot;
  cpusix.hwdata <= cpusi.hwdata;
  cpusix.hmastlock <= cpusi.hmastlock;
  cpusix.hready <= cpusi.hready;
  cpusix.hsel(0 to nextslv - 1) <= cpusi.hsel(0 to nextslv - 1);
  cpusix.hsel(nextslv) <= cpusi.hsel(nextslv);
  cpusix.hsel(nextslv + 1 to 15) <= (others => '0');
  -- The remaining ahbsi fields must also be forwarded to the CPU core. In
  -- particular testen/testrst/scanen/testoen/testin and endian: if left
  -- unassigned they default to 'U', and the core derives its scan-mux controls
  -- from ahbsi.testen/testrst, so 'U' poisons state across the whole core in
  -- simulation (X-propagation -> random mispredicts, dropped writebacks).
  cpusix.hmaster <= cpusi.hmaster;
  cpusix.hmbsel <= cpusi.hmbsel;
  cpusix.hirq <= cpusi.hirq;
  cpusix.testen <= cpusi.testen;
  cpusix.testrst <= cpusi.testrst;
  cpusix.scanen <= cpusi.scanen;
  cpusix.testoen <= cpusi.testoen;
  cpusix.testin <= cpusi.testin;
  cpusix.endian <= cpusi.endian;

  genrot: for i in 0 to nextslv - 1 generate
    cpuso(i) <= ahbso(i);
  end generate;
  cpuso(nextslv) <= ahbso_apbctrl;
  -- Clear above 5 internal AHB slaves:
  -- aclint, imsic, (a)plic, dummy
  cpuso(cpuso'high downto nextslv + 4 + DUAL_PLIC + 1) <= (others => ahbs_none);

  ap0: apbctrl
    generic map (
      hindex  => nextslv,
      haddr   => APBC_HADDR,
      hmask   => APBC_HMASK,
      nslaves => nextapb + 3,
      debug   => 0
      )
    port map (
      rst  => rstn,
      clk  => clk,
      ahbi => cpusix,
      ahbo => ahbso_apbctrl,
      apbi => cpuapbi,
      apbo => cpuapbo
      );

  -- Shift up any external APB slaves to fit 3 internal ones:
  -- uart, gptime, etrace
  noextapb: if nextapb = 0 generate
    apbi                    <= cpuapbi;
    cpuapbix                <= cpuapbi;
    cpuapbo(APBUART_PINDEX) <= apbo_uart;
    cpuapbo(GPTIME_PINDEX)  <= apbo_gptime;
    cpuapbo(ETRACE_PINDEX)  <= apbo_etrace;
  end generate;
  doshiftapb: if nextapb > 0 generate
    apbi.pirq <= cpuapbi.pirq;
    apbi.paddr <= cpuapbi.paddr;
    apbi.penable <= cpuapbi.penable;
    apbi.pwrite <= cpuapbi.pwrite;
    apbi.pwdata <= cpuapbi.pwdata;
    apbi.psel(3 to nextapb + 2) <= cpuapbi.psel(0 to nextapb - 1);
    apbi.psel(0 to 2) <= (others => '0');
    apbi.psel(nextapb + 3 to 15) <= (others => '0');

    cpuapbix.pirq <= cpuapbi.pirq;
    cpuapbix.paddr <= cpuapbi.paddr;
    cpuapbix.penable <= cpuapbi.penable;
    cpuapbix.pwrite <= cpuapbi.pwrite;
    cpuapbix.pwdata <= cpuapbi.pwdata;
    cpuapbix.psel(3 to nextapb + 2) <= cpuapbi.psel(0 to nextapb - 1);
    cpuapbix.psel(0 to 2) <= (others => '0');
    cpuapbix.psel(nextapb + 3 to 15) <= (others => '0');
    cpuapbo(0) <= apbo_uart;
    cpuapbo(1) <= apbo_gptime;
    cpuapbo(2) <= apbo_etrace;
    genrotapb: for i in 3 to nextapb + 2 generate
      cpuapbo(i) <= apbo(i - 3);
    end generate;
  end generate;
  cpuapbo(nextapb + 3 to cpuapbo'high) <= (others => apb_none);

  ----------------------------------------------------------------------------
  -- Processor(s)
  ----------------------------------------------------------------------------
  cpuloop: for c in 0 to ncpu-1 generate
    core: noelvcpu
      generic map (
        hindex   => c,
        fabtech  => fabtech,
        memtech  => memtech,
        cached   => cached,
        wbmask   => wbmask,
        busw     => busw,
        cmemconf => cmemconf,
        rfconf   => rfconf,
        fpuconf  => fpuconf,
        tcmconf  => tcmconf,
        mulconf  => mulconf,
        intcconf => intcconf,
        mnintid  => nintid(c),
        snintid  => nintid(c),
        gnintid  => gnintid(c),
        disas    => disas,
        pbaddr   => 16#90000#,
        cfg      => cfg,
        scantest => scantest
      )
      port map (
        clk    => clk,
        gclk   => gclk(c),
        rstn   => rstn,
        ahbi   => cpumi,
        ahbo   => cpumo(c),
        ahbsi  => cpusix,
        ahbso  => cpuso,
        irqi   => irqi(c),
        irqo   => irqo(c),
        dbgi   => dbgi(c),
        dbgo   => dbgo(c),
        tpo    => tpo(c),
        cnt    => cnt(c),
        pwrd   => pwrd(C)
      );

  end generate;


  cpu0errn <= not dbgo(0).error;


  ----------------------------------------------------------------------------
  -- Debug and tracing module
  ----------------------------------------------------------------------------
  dm0 : dmnv
  generic map(
    fabtech   => fabtech,
    memtech   => memtech,
    ncpu      => ncpu,
    ndbgmst   => ndbgmst,
    -- Conventional bus
    cbmidx    => AHBB_HMINDEX,
    -- PnP
    dmhaddr   => DM_HADDR,
    dmhmask   => DM_HMASK,
    pnpaddrhi => 16#FFF#,
    pnpaddrlo => 16#FFF#,
    dmslvidx  => DM_HINDEX,
    dmmstidx  => AHBB_HMINDEX,
    -- Trace
    tbits     => 30,
    --
    scantest  => 0,
    -- Pipelining
    plmdata   => 0)
  port map(
    clk      => clk,
    rstn     => rstn,
    -- Debug-link interface
    dbgmi    => dbgmi,
    dbgmo    => dbgmo,
    -- Conventional AHB bus interface
    cbmi    => cpumi,
    cbmo    => cpumo(AHBB_HMINDEX),
    cbsi    => cpusix,
    --
    dbgi    => dbgo,
    dbgo    => dbgi,
    dsui    => dsui,
    dsuo    => dsuo);

  dsui.enable <= dsuen;
  dsui.break  <= dsubreak;

  etrace : if trace /= 0 generate
    e : for i in 0 to ncpu - 1 generate
      eto(i) <= tpo(i).eto;
    end generate;

  x : etracenv
      generic map(
        ext_c   => 1,
        ncpu    => ncpu,
        pindex  => ETRACE_PINDEX,
        paddr   => ETRACE_PADDR,
        pmask   => ETRACE_PMASK,
        pirq    => ETRACE_PIRQ
      )
      port map(
        rstn    => rstn,
        clk     => clk,
        apbi    => cpuapbix,
        apbo    => apbo_etrace,
        eto     => eto,
        etso    => etso,
        etsi    => etsi
      );
  end generate;
  notrace : if trace = 0 generate
    apbo_etrace <= apb_none;
    etso <= (others => nv_etrace_sink_out_none);
  end generate;

  ----------------------------------------------------------------------------
  -- Standard UART
  ----------------------------------------------------------------------------
  uart_gen : if UART16550 = 0 generate
    uart0: apbuart
      generic map (
        pindex   => APBUART_PINDEX,
        paddr    => APBUART_PADDR,
        pmask    => APBUART_PMASK,
        console  => 1,
        pirq     => 1,
        parity   => 1,
        flow     => 0,
        fifosize => 8,
        abits    => 8,
        sbits    => 12
        )
      port map (
        rst   => rstn,
        clk   => clk,
        apbi  => cpuapbix,
        apbo  => apbo_uart,
        uarti => uarti,
        uarto => xuarto
        );
    uarto <= xuarto;
  end generate;

  uart16550_gen : if UART16550 = 1 generate
    uart0: apbuart_16550
      generic map (
        pindex   => APBUART_PINDEX,
        paddr    => APBUART_PADDR,
        pmask    => APBUART_PMASK,
        console  => 1,
        pirq     => 1,
        flow     => 1,
        fifomode => 1,
        abits    => 8,
        sbits    => 12
        )
      port map (
        rst   => rstn,
        clk   => clk,
        apbi  => cpuapbix,
        apbo  => apbo_uart,
        uarti => uarti,
        uarto => xuarto
        );
    uarto <= xuarto;
  end generate;


-- pragma translate_off
-- pragma translate_on

  ----------------------------------------------------------------------------
  -- Timer
  ----------------------------------------------------------------------------
  gpt0: gptimer
    generic map (
      pindex  => GPTIME_PINDEX,
      paddr   => GPTIME_PADDR,
      pmask   => GPTIME_PMASK,
      pirq    => 2,
      sepirq  => 1,
      sbits   => 16,
      ntimers => 2,
      nbits   => 32,
      wdog    => 0,
      ewdogen => 0,
      glatch  => 0,
      gextclk => 0,
      gset    => 0,
      gelatch => 0,
      wdogwin => 0
      )
    port map (
      rst  => rstn,
      clk  => clk,
      apbi => cpuapbix,
      apbo => apbo_gptime,
      gpti => gpti,
      gpto => gpto
      );

  gpti <= (
    dhalt =>  dbgo(0).stoptime,
    extclk => '0',
    wdogen => '0',
    latchv => (others => '0'),
    latchd => (others => '0')
    );

  ----------------------------------------------------------------------------
  -- Interrupt controller
  ----------------------------------------------------------------------------

    -- ACLINT -----------------------------------------------------------
    aclint0 : aclint_ahb
      generic map (
        hindex    => ACLINT_HINDEX,
        haddr     => ACLINT_HADDR,
        hmask     => ACLINT_HMASK,
        hirq1     => WATCHDOG_HIRQ1,
        hirq2     => WATCHDOG_HIRQ2,
        ncpu      => ncpu,
        sswi      => S_EN
        )
      port map (
        rst       => rstn,
        clk       => clk,
        rtc       => rtc,
        ahbi      => cpusix,
        ahbo      => cpuso(ACLINT_HINDEX),
        halt      => dbgo(0).stoptime,
        irqi      => eip,
        irqo      => irqi
        );

    rtc0 : process(clk)
    begin
      if rising_edge(clk) then
        rtc <= not rtc;
        if rstn = '0' then
          rtc <= '0';
        end if;
      end if;
    end process;

  aia_gen : if AIA_en /= 0 generate
    -- IMSIC  ---------------------------------------------------------
    imsic0 : imsic_ahb
     generic map (
       hindex            => IMSIC_HINDEX,
       haddr             => IMSIC_HADDR,
       ncpu              => ncpu,
       GEILEN            => GEILEN,
       groups            => groups,
       S_EN              => S_EN,
       H_EN              => H_EN,
       mnidentities_vector   => nintid,
       snidentities_vector   => nintid,
       gnidentities_vector   => gnintid
       )
     port map (
       rst        => rstn,
       clk        => clk,
       ahbi       => cpusix,
       ahbo       => cpuso(IMSIC_HINDEX),
       irq_ack    => imsic_ack,
       irqo       => imsic_irq
       );
    imsic_ack_gen : for i in 0 to ncpu-1 generate
      imsic_ack(i) <= '1';
    end generate;


    -- GRAPLIC ----------------------------------------------------------
    aplic0 : graplic_ahb
      generic map (
        hmindex             => APLIC_HMINDEX,
        hsindex             => APLIC_HSINDEX,
        haddr               => APLIC_HADDR,
        nsources            => NAHBIRQ-1,
        ncpu                => ncpu,
        branches            => branches,
        doms_per_branch     => doms_per_branch,
        endianness          => 0,
        S_EN                => S_EN,
        H_EN                => H_EN,
        GEILEN              => GEILEN,
        grouped_harts       => 0,
        mmsiaddrcfg_fixed   => 1,
        mbase_PPN           => mbase_PPN,
        sbase_PPN           => sbase_PPN,
        mLHXS               => mLHXS,
        sLHXS               => sLHXS,
        HHXS                => HHXS,
        LHXW                => LHXW,
        HHXW                => HHXW,
        direct_delivery     => 1,
        IPRIOLEN            => 8,
        nEIID               => neiid,
        preset_active_harts => preset_active_harts_default
        )
      port map (
        rstn      => rstn,
        clk       => clk,
        ahbmi     => cpumi,
        ahbmo     => cpumo(APLIC_HMINDEX),
        ahbsi     => cpusix,
        ahbso     => cpuso(APLIC_HSINDEX),
        meip      => aplic_meip,
        seip      => aplic_seip
        );
  end generate aia_gen;


  old_interrupt_gen : if AIA_en = 0 or AIA_en = 2 generate
    -- PLIC -----------------------------------------------------------
    grplic0 : grplic_ahb
      generic map (
        hindex            => PLIC_HINDEX,
        haddr             => PLIC_HADDR,
        hmask             => PLIC_HMASK,
        nsources          => NAHBIRQ,
        ncpu              => ncpu,
        priorities        => 8,
        pendingbuff       => 1,
        irqtype           => 1,
        thrshld           => 1
        )
      port map (
        rst               => rstn,
        clk               => clk,
        ahbi              => cpusix,
        ahbo              => cpuso(PLIC_HINDEX),
        irqo              => plic_eip
        );

        -- Tie non implemented AHB outputs
      no_aia : if AIA_en = 0 generate
        cpuso(IMSIC_HINDEX)  <= ahbs_none;
        cpumo(APLIC_HMINDEX) <= ahbm_none;
        --cpuso(APLIC_HSINDEX) <= ahbs_none;
      end generate;

        -- IRQ Interface
        eip_gen : for i in 0 to ncpu-1 generate
          old_eip(i).meip     <= plic_eip(i * 4);
          old_eip(i).seip     <= plic_eip(i * 4 + 1);
          old_eip(i).ueip     <= plic_eip(i * 4 + 2);
          old_eip(i).heip     <= plic_eip(i * 4 + 3);
          old_eip(i).hgeip    <= (others => '0'); -- Only with APLIC
          old_eip(i).mtip     <= '0';
          old_eip(i).msip     <= '0';
          old_eip(i).ssip     <= '0';
          old_eip(i).stime    <= (others => '0');
          old_eip(i).nmirq    <= (others => '0');
        end generate eip_gen;
  end generate old_interrupt_gen;


  eip_select : process(imsic_irq, old_eip, aplic_meip, aplic_seip
  ) is
  begin
    eip <= (others => nv_irq_in_none);
    if AIA_en = 0 or AIA_en = 2 then
      -- Old PLIC is implemented 
      eip <= old_eip;
    end if;
    if AIA_en /= 0 then
      -- AIA is implemented
      for i in 0 to ncpu-1 loop
        eip(i).imsic      <= imsic_irq(i);
        eip(i).aplic_meip <= aplic_meip(i);
        eip(i).aplic_seip <= aplic_seip(i);
      end loop;
    else
      -- AIA is not implemented 
      -- tie unused signals
      for i in 0 to ncpu-1 loop
        eip(i).imsic      <= imsic_irq_none;
        eip(i).aplic_meip <= '0';
        eip(i).aplic_seip <= '0';
      end loop;
    end if;
    for i in 0 to ncpu-1 loop
      eip(i).nmirq <= (others => '0');
    end loop;
  end process;


    -- nirq_zero : for i in 0 to ncpu-1 generate
    --   irqi(i).nmirq <= (others => '0');
    -- end generate nirq_zero;



  -----------------------------------------------------------------------------
  -- Simulation report
  -----------------------------------------------------------------------------
-- pragma translate_off
  simrep: process
  begin
    grlib.stdlib.print("noelvsys: NOELV subsystem simulation started.");
    wait;
  end process;

  timestamp_logger: process
  begin
    while true loop
      wait for 10 us;
      grlib.stdlib.print("noelvsys: [Simulation Time: " & time'image(now) & "]");
    end loop;
  end process;
-- pragma translate_on
end;
