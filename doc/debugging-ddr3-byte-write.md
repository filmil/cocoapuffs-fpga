# Case study: debugging the DDR3 byte-write bug (OpenSBI hang on NOEL-V)

This documents how we found a hardware bug — **sub-word (byte) writes to DDR3
were broken** — that manifested as OpenSBI hanging early in boot on the a200t
NOEL-V board. The bug was invisible to every "obvious" memory test and took a
long chain of narrowing to reach. The strategies below are the transferable
part; the specific bug is in section *The bug*.

## TL;DR

- **Symptom:** OpenSBI ran its code (from 0x40000) but hung in `sbi_domain_init`;
  its console output was 4×-garbled and unreadable.
- **Root cause:** `ip/bridges/ahb2wb_bridge.vhdl` hardwired the Wishbone byte
  strobes (`sel`) to all-ones. A byte store (`sb`) therefore wrote *all four
  bytes* of the word (the NOEL-V replicates the byte across the data bus), so
  `sb 0xAA` produced `0xAAAAAAAA`. OpenSBI's byte-wise `sbi_memcpy`/`sbi_memset`
  silently corrupted the heap → domain regions zeroed → `SBI_EINVAL` → hang.
- **Fix:** derive `sel` from the AHB `hsize`/`haddr[1:0]` (one `case`); see the
  same file. Regression test: `//ip/bridges/tool.nvc:ahb2wb_bridge_test`.

## What made this hard

The failure was in *firmware running on real DDR3*, but:

- The same firmware **passed in simulation** (which used clean BRAM, not the
  DDR3 path).
- The console was garbled, so the error message was unreadable.
- Standalone RAM, atomics, and ihex-load tests on the board **all passed** —
  because they only ever used *aligned word/dword* accesses. The broken access
  width (byte stores) was never exercised by any of them.

## Strategies that worked

### 1. Differential debugging: sim vs hardware

The single most useful framing was "same firmware, sim passes, hardware fails —
so enumerate every way the two environments differ." That immediately pointed at
the memory subsystem (BRAM vs DDR3) rather than the firmware logic, and kept us
from re-reading OpenSBI source looking for a logic bug that wasn't there.

### 2. Bypass the broken observability channel

The console was garbled (4×), so we couldn't read OpenSBI's own diagnostics. The
breakthrough was a **raw bit-bang tracer**: a tiny helper that pokes the UART
directly (poll status bit, scaler 42) using the *exact method the passing
standalone tests used*, instead of going through OpenSBI's console driver. It
printed cleanly where the console garbled — which both (a) gave us readable
output and (b) proved the garbling lived in the console *path*, not the UART.

Lesson: when your normal logging is unreliable, build the dumbest possible
side-channel that you've independently shown to be clean, and use *that*.

### 3. Progressive narrowing with one-character tracers

We instrumented OpenSBI in layers, each upload answering one question:

1. Which coldboot step fails? → tag per step (`S` scratch, `H` heap, `D` domain).
   Result: `D = 0xFFFFFFFD` (`-3`, `SBI_EINVAL`) from `sbi_domain_init`.
2. Which input to that function is wrong? → dump `fw_start`, `fw_rw_offset`,
   `fw_size`, `hart_count`, `next_mode`, `next_addr`. Result: **all correct**.
3. Which internal check fails? → tag each of `sanitize_domain`'s seven
   `SBI_EINVAL` returns. Result: check #7 (`next_addr` "can't execute").
4. Why? → dump the domain's memory regions. Result: the region list was *empty*.
5. When did it go empty? → dump regions **at build time** vs **after the sort**.
   Result: correct after building (written via 64-bit `sd`), zeroed after the
   sort — and the sort's only memory op is `swap_region` → `sbi_memcpy`.

Each step was cheap and falsifiable. Crucially, when a hypothesis was *refuted*
(the inputs were all correct), that was just as valuable as a confirmation — it
deleted a whole branch of the search.

### 4. Isolate with standalone probes that vary one axis

Alongside the in-OpenSBI tracing, we wrote tiny freestanding programs uploaded
to the same board (`//bin/noelv_memtest`, `noelv_atomictest`, `noelv_datatest`,
`noelv_bytetest`). Each isolated one hypothesis: bulk RAM integrity, atomics,
ihex `.data` placement, and finally **byte writes**. The first three passed and
*looked* like they exonerated memory — the trap we nearly fell into.

### 5. Match the access *pattern* of the failing code, not just "does memory work"

The key realization: every passing test used `sw`/`sd`/AMO — **aligned word and
dword** accesses. OpenSBI fails inside `sbi_memcpy`, which is **byte-wise**
(`char *`, → `sb`/`lb`). The one axis no probe had varied was *transfer width*.
`noelv_bytetest` did exactly that and returned `BYTE BAD got 0xAAAAAAAA expected
0x443322AA` — the smoking gun.

Lesson: "memory works" is not one property. Width, alignment, burst, and
atomicity are separate paths through the fabric; test the one your victim code
actually uses.

### 6. Reproduce in a fast sim and lock it with a regression test

Once the mechanism was understood (byte strobes dropped in the AHB→WB bridge),
we wrote a unit testbench with a mock Wishbone slave that *honors* `sel`. With
the old RTL it reproduces `got 0xAAAAAAAA`; with the fix every byte/halfword/word
case passes. That test now guards the fix and documents the contract.

## The bug

`ip/bridges/ahb2wb_bridge.vhdl` translated AHB writes to Wishbone but drove:

```vhdl
wb_wbo.sel <= (others => '1');   -- every byte enabled, always
```

It never captured the AHB `hsize`. On a byte/halfword store the NOEL-V drives the
byte replicated across all lanes; with all strobes asserted, the slave wrote the
whole word. The fix computes `sel` from `hsize` + `haddr[1:0]` in the address
phase and threads it through the clock-domain crossing to `wb_wbo.sel`.

## Tooling notes

- The NVC tests in `ip/.../tool.nvc` need grlib compiled with the same VHDL
  standard as the test (`--std=2008`). grlib defaults to VHDL-1993, which yields
  `design unit depends on 1993 version of STD.STANDARD but conflicting 2008
  version has been loaded`. Fixed by pinning `--@grlib//:vhdl_standard=2008` in
  `.bazelrc`. That mismatch also floods nvc's output with `Note: ... obsolete`
  lines that bury the real error — fixing the standard makes diagnostics legible.
- `vhdl_test` doesn't forward a `tags` attribute, so the full-memory sweep can't
  yet be tagged `manual`: filed as filmil/bazel_rules_nvc#98.
