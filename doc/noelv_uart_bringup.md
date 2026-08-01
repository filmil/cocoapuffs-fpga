<!-- SPDX-License-Identifier: Apache-2.0 -->
# NOEL-V APB UART bring-up

How we got the NOEL-V RISC-V core in `//boards/noelv` to boot from a small
program and successfully transmit on its APB UART, and the bugs we had to fix
along the way.

## Goal

`//boards/noelv:vcd_only` runs the testbench `tb_noelvsys_only`, which
instantiates `gaisler.noelvsys` (a NOEL-V rv64 core + AHB/APB subsystem). The
boot program `bin/noelv_boot/main.S` configures the NOEL-V APB UART and writes
the string `"halt."`. The goal was to see that string come out of the UART.

The starting symptom: **no activity at all on the UART transmit line (`txd`).**

## TL;DR

The visible "no UART activity" symptom had several independent causes stacked on
top of each other. In the order we peeled them back:

1. **Wrong UART address.** The program wrote to `0xFFF90000`, which is the AHB
   plug&play I/O area, not the UART. The UART is at `0xFF900000`.
2. **A custom AHB→Wishbone bridge on the fetch path** was extremely slow and
   non-ideal for the core's burst fetches. We replaced it with a direct
   AHB-slave RAM (`ip/bridges/ahb_bram.vhdl`).
3. **A dead AHB slave that never asserted `hready`.** The `0x0` region was
   mapped to an `ahb2wb_bridge` whose Wishbone side was unconnected. A
   *speculative* instruction fetch to `0x0` hung forever and froze the whole
   core.
4. **The root cause: `'U'` / X-propagation in the core.** `noelvsys.vhd` never
   drove the scan/test/endian fields of the CPU's internal AHB slave bus, so the
   core's scan muxes were driven by `'U'`. In simulation this corrupted state
   across the entire core (random branch mispredicts, dropped register writes).
5. **Wrong baud rate** for the testbench's UART receiver. Cosmetic for "is it
   alive", but required for the testbench to actually decode the bytes.

After all five were fixed, the core boots, runs the program, and the testbench
receives `"halt."`.

## The investigation, layer by layer

The only observable was the VCD, so every step below was done by reading signals
out of `bazel-bin/boards/noelv/tool.vivado/sim_only.vcd`.

### 1. The UART address was in the plug&play shadow

The program did `lui t0, 0xFFF90` and wrote to `0xFFF90000`. But in GRLIB an AHB
slave decodes on address bits `[31:20]`:

- The APB bridge (`apbctrl`) is at `APBC_HADDR = 0xFF9`, `HMASK = 0xFFF`, so it
  owns `0xFF900000`–`0xFF9FFFFF`.
- Inside it the UART decodes on bits `[19:8]` at `APBUART_PADDR = 0x000`, so the
  UART registers are at **`0xFF900000`** (data `+0`, status `+4`, control `+8`,
  scaler `+C`).

`0xFFF` (the top nibble of `0xFFF90000`) is `AHBC_IOADDR` — the AHB controller's
plug&play I/O area, instantiated with `shadow => 1`, which *hides* any slave
mapped there. So stores to `0xFFF90000` landed in read-only plug&play space and
never reached the UART. Fix: `lui t0, 0xFF900`.

### 2. The fetch path went through a slow AHB→WB bridge

The boot RAM was reached through `ip/bridges/ahb2wb_bridge.vhdl`, a clock-domain
crossing bridge that takes ~20 clocks per beat and serves the core's burst
fetches as independent single transfers. It returned correct data but was a poor
match for an instruction cache line fill. We replaced it with a new direct
AHB-slave block RAM, `ip/bridges/ahb_bram.vhdl` (zero wait state, one word per
clock, memfile init, byte-enabled writes), and wired it in as the boot RAM. This
made fetches fast and correct but did **not**, by itself, make the core run —
which told us the memory subsystem was not the real problem.

### 3. A speculative fetch to `0x0` hung the core

Tracing the core's AHB master (`core/u0/bif0/x0/ahbo_*`) showed the core fetch
the program correctly and then issue an instruction fetch (`BIFOP_ILFET`) to
`0x00000000`, where `hready` never came back. The `trap` signal never asserted,
so this was *not* an architectural trap to `mtvec=0` — it was a **speculative**
fetch from an uninitialized branch predictor.

`0x0` was mapped to slave 1, an `ahb2wb_bridge` whose Wishbone side
(`noelv_wb_per`) was never driven, so it never asserted `hready`. A hung AHB
transfer cannot be squashed, so the speculative fetch froze the core. We
replaced that dead slave with a responding `ahb_bram`, after which the hang
disappeared.

General rule this taught us: **every AHB region must respond.** A slave that
claims an address range but never drives `hready` will freeze NOEL-V on any
*speculative* access, not just a real one.

### 4. Root cause: `'U'` / X-propagation from undriven scan controls

With the hang gone, the core still misbehaved, and crucially the behaviour was
**inconsistent and program-dependent** — shuffle a few `nop`s and it failed
differently. That is the signature of `'U'`/X propagation in simulation, not a
deterministic logic bug. The repo even has prior art for this class of problem
(`doc/using_unresolved_signals.md`, and a muntjac patch that initializes
registers for xsim).

We ran an **X-scan**: parse the VCD, track every signal to steady state, and
list the ones stuck at `x`/`u`. 346 core signals were undefined, including the
register file outputs, the branch predictor tables, and — the smoking gun — the
scan/test control signals `testen`, `testrst`.

Comparing levels:

| signal | at `noelvsys` port | inside the CPU (`.../c0/c0/`) |
|--------|--------------------|-------------------------------|
| `testen`  | `0` | **`X`** |
| `testrst` | `1` | **`X`** |

So the value was lost *between* the `noelvsys` port and the core. The cause is
in `third_party/grlib/noelvsys.vhd`: the CPU's internal AHB slave bus `cpusix`
(which feeds the core's `ahbsi`) is assembled field by field, and only
`haddr/hwrite/htrans/hsize/hburst/hprot/hwdata/hmastlock/hready/hsel` were
assigned. The fields `testen`, `testrst`, `scanen`, `testoen`, `testin`,
`endian` (and `hmaster`, `hmbsel`, `hirq`) were **never assigned**, so they sat
at `'U'`.

The NOEL-V core derives its scan-mux selects directly from `ahbsi.testen` /
`ahbsi.testrst` (`cpucorenv.vhd`). With `testen = 'U'`, the scan mux in every
flip-flop and RAM resolves to `X`, and that `X` floods the whole core. The two
mysteries we had chased were both just downstream of this:

- random branch mispredicts → the speculative `0x0` fetch of step 3;
- dropped register writebacks → `lui t0, 0xFF900` never landed, so `t0 = 0` and
  every "UART" store went to address `0x0` instead of `0xFF900000`.

**The fix** is to forward the missing fields, right after the `cpusix.hsel`
assignments in `noelvsys.vhd`:

```vhdl
cpusix.hmaster <= cpusi.hmaster;
cpusix.hmbsel  <= cpusi.hmbsel;
cpusix.hirq    <= cpusi.hirq;
cpusix.testen  <= cpusi.testen;
cpusix.testrst <= cpusi.testrst;
cpusix.scanen  <= cpusi.scanen;
cpusix.testoen <= cpusi.testoen;
cpusix.testin  <= cpusi.testin;
cpusix.endian  <= cpusi.endian;
```

After this, the core executes the program: `t0 = 0xFF900000`, and it writes the
scaler (`0xFF90000C`), control (`0xFF900008`), and data (`0xFF900000`) registers
at the correct addresses, and `txd` starts toggling.

### 5. Baud rate for the testbench receiver

The program set the UART scaler to `2`, giving `50 MHz / (8 * (2+1)) ≈ 2.08
Mbaud`, but the testbench's VUnit `uart_slave` decodes at a fixed `200 kbaud`.
So `txd` was correct but the bytes could not be decoded. For ~200 kbaud at 50
MHz the scaler is `30` (`50 MHz / (8 * (30+1)) ≈ 201.6 kbaud`, ~0.8% error, well
within UART tolerance).

## How to verify

The testbench is now self-checking. Its main process waits for the string and a
watchdog fails the run if it never arrives:

```vhdl
wait_for_string(net, uart_rx_stream, "halt.");
```

Run it:

```
bazel build //boards/noelv:vcd_only
```

and check `bazel-bin/boards/noelv/tool.vivado/sim_only.sim.log`:

```
INFO: Noel-V released from reset, waiting for 'halt.' on UART...
INFO: Received 'halt.' on the NOEL-V APB UART -- PASS
$finish called at time : 254130 ns ... Line 98
```

The `$finish` comes from `std.env.finish` (clean exit), not the watchdog. At
~200 kbaud, five characters take ~250 us, so the run needs the full default
`sim_duration` (do not shorten it for this check).

The `ahb_bram` block RAM has its own VUnit test:

```
bazel test //ip/bridges/tool.vivado:ahb_bram_test
```

## Diagnostic techniques used (worth keeping)

- **VCD X-scan.** Parse the VCD, hold each signal's value to steady state, and
  print the ones stuck at `x`/`u` in the core scopes. This is what found the
  undriven `testen`. Any persistent `x`/`u` on a control path after reset is a
  bug; scan/test inputs are the usual suspects.
- **The core busif signals.** `core/u0/bif0/x0/` exposes the real AHB master
  (`ahbo_haddr`, `ahbo_htrans`, `ahbi_hready`) and the cache-controller request
  (`bifi_bifop`, `bifi_busaddr`, `bifi_stdata`). `bifi_bifop` distinguishes an
  instruction fetch (`BIFOP_ILFET = 1011`) from a data line fetch
  (`BIFOP_DLFET = 1010`) and a store (`BIFOP_STORE = 1000`); `bifi_busaddr` /
  `bifi_stdata` show the exact address and data the core computed (which is how
  we proved `t0 = 0`).
- **`ahb_bram` debug signals.** The block RAM exposes `dbg_haddr` / `dbg_htrans`
  / `dbg_hwrite` / `dbg_hsel` / `dbg_hrdata` so AHB activity at the boot RAM is
  visible in the VCD (the records on the real bus are not dumped by xsim).
- **Decoding `txd`.** Sample the line at the DUT's bit period to read out the
  transmitted bytes directly, independent of the testbench's receiver.

## Files changed

| File | Change |
|------|--------|
| `third_party/grlib/noelvsys.vhd` | Forward `testen/testrst/scanen/testoen/testin/endian` (+`hmaster/hmbsel/hirq`) on `cpusix` to the CPU core — the root-cause fix. Also `APBC_HADDR = 0xFF9` and `UART16550 = 1` (see below). |
| `bin/noelv_boot/main.S` | UART base `0xFF900000`; UART init + `"halt."` transmit (16550 sequence, see below). |
| `ip/bridges/ahb_bram.vhdl` | New direct AHB-slave block RAM. |
| `ip/bridges/ahb_bram.test.vhdl` | New VUnit test for it. |
| `boards/noelv/tb_noelvsys_only.vhdl` | Boot RAM and `0x0` region both via `ahb_bram`; `cfg = 4`; self-checking `wait_for_string("halt.")` + watchdog. |
| `ip/bridges/{BUILD,tool.nvc,tool.vivado}` | Wire `ahb_bram` into the libraries and add the test targets; add `apbuart_16550.vhd` to the gaisler libraries. |

## UART: the standard 16550

`noelvsys` can instantiate either the Gaisler `apbuart` or a standard 16550, via
the local constant `UART16550`. The bring-up above was done with the Gaisler
`apbuart` (8x baud, scaler at `+0xC`); the project now uses the **16550**
(`UART16550 = 1`), the de-facto PC-style UART, at the same base `0xFF900000`.

Switching requires three things:

1. Add `lib/gaisler/uart/apbuart_16550.vhd` to the `gaisler` /
   `gaisler_sim_custom` libraries (it is not compiled in otherwise, so the
   `apbuart_16550` instantiation would not elaborate).
2. Set `UART16550 := 1` in `noelvsys.vhd`.
3. Rewrite the boot program for the 16550 register map — it is completely
   different from the Gaisler UART:

| offset | Gaisler `apbuart` | standard 16550 |
|--------|-------------------|----------------|
| `+0x0` | data | THR / RBR / DLL |
| `+0x4` | status | IER / DLM |
| `+0x8` | control | IIR (r) / FCR (w) |
| `+0xC` | scaler | LCR (bit 7 = DLAB) |
| `+0x14`| — | LSR (bit 5 = THRE) |

16550 init is the classic sequence: set `LCR.DLAB`, write the divisor to
`DLL`/`DLM`, set 8N1 in `LCR`, enable the FIFO in `FCR`, then write characters
to `THR`. The 16550 uses **16x** oversampling, `baud = sysclk / (16 ×
(divisor+1))`, so for ~200 kbaud at 50 MHz the divisor is `15`
(≈195.3 kbaud, within the receiver's tolerance). The 16-deep TX FIFO holds all
five characters, so no `THRE` polling is needed for this program.

Verified the same way: `bazel build //boards/noelv:vcd_only` then look for
`Received 'halt.' ... PASS` in `sim_only.sim.log` (the startup banner shows
`fifo 16`, the 16550's FIFO, instead of the Gaisler UART's `fifo 8`).

## Selecting the baud rate (simulation vs hardware)

The boot program picks the UART divisor from a compile-time constant `SIM_FAST`
(`bin/noelv_boot/main.S` is a `.S` file, so it is run through `cpp`):

- `SIM_FAST = 1` (default): fast simulation rate, divisor `15` (~195 kbaud),
  matched to the testbench's 200 kbaud receiver so the self-checking sim stays
  short and `wait_for_string("halt.")` passes.
- `SIM_FAST = 0`: realistic **115200 bps** (divisor `26`), for real hardware.
  (Divisors assume a 50 MHz UART clock; adjust if the board clock differs.)

This is wired into Bazel via a `string_flag` plus a configuration transition
(`bin/noelv_boot/baud.bzl`):

- `--//bin/noelv_boot:uart_mode=hw` builds everything in 115200 mode (`:memh`
  and friends default to `sim`).
- The transition targets `:memh_sim` / `:memh_hw` / `:disasm_hw` pin a mode
  regardless of the global flag, so both images can be produced in one build
  (in distinct configurations).

Verify: `bazel build //bin/noelv_boot:disasm` shows `li t1,15`, while
`bazel build //bin/noelv_boot:disasm_hw` shows `li t1,26`.

## Transplanting to the full board (`board.arch_rtl.vhdl`)

The full a200t board is a **dual-core** SoC: a SERV core and the NOEL-V
subsystem share one UART through a mux. SERV boots first (from `bram0`), writes
`0x3` to the percontrol register at `0x40000040` — bit 0 switches the UART mux
to NOEL-V (`uart1_txd <= txd_serv when perctl_reg(0)='0' else txd_noelv`),
bit 1 releases NOEL-V from reset (`noelv_reset_n <= (not reset) and
perctl_reg(1)`) — then NOEL-V boots and transmits "halt." on the now-muxed
UART. `tb.arch_sim.vhdl` waits for "halt." with a watchdog.

Most fixes carry over for free because **`noelvsys.vhd` is shared**: the
`cpusix` testen fix and `UART16550 = 1` apply to the board automatically. The
board-specific changes were:

- **Boot RAM**: replaced the `ahb2wb_bridge` + `wb.bram` on NOEL-V's slave 0
  with a direct `bridges.ahb_bram` on the AHB clock (`clk50`).
- **`cfg`**: `0 -> 4` on the `noelvsys` instantiation (the proven-booting
  config).
- NOEL-V's slave 1 (the `0x0` region) stays on the **DDR3** main RAM. With the
  testen fix the predictor is deterministic, so NOEL-V does not speculatively
  fetch `0x0`; its boot only touches slave 0 (boot RAM) and the UART, never
  DDR3 — so no responding low-region RAM is needed here.
- **Test duration**: the `:test` target now runs `_SIM_DURATION_NS` (300 us) so
  the full "halt." (~265 us at ~195 kbaud) arrives before the watchdog.

Run it with `bazel test //boards/noelv/tool.vivado:test`. The full-board sim
(SERV + NOEL-V + DDR3 model) is heavier than the isolated `tb_noelvsys_only`,
but still runs in a handful of minutes.

## Notes for next steps

- This setup should drop into `boards/noelv/tb.arch_sim.vhdl`, which already
  uses the same `uart_slave` + `wait_for_string("halt.")` pattern at 200 kbaud.
- The NVC test path (`//ip/bridges/tool.nvc:ahb_bram_test`) is **pre-existing
  broken**: the root `//:grlib` library is analyzed as VHDL-1993 and cannot link
  into a 2008 test library (the existing `ahb2wb_bridge_test` fails the same
  way). The working unit test is the xsim/Vivado one.
- `cfg = 4` (a minimal core) was chosen during debugging. The bigger `cfg = 0`
  core may well boot now that the X-propagation is gone — worth retrying if the
  larger configuration is wanted.
