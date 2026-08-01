# Fuchsia boot-shim fault: simulation diagnosis

Goal: boot **Fuchsia** (Zircon) on the a200t NOEL-V (RV64). Fuchsia's RISC-V port
boots through a Linux-boot-protocol shim (`//third_party/fuchsia:riscv64-boot-shim`,
a Linux `Image`) that OpenSBI hands off to in S-mode; the shim then launches Zircon.

## Hardware symptom (log42, pre-cache-fix bitstream)

OpenSBI boots, prints the full boot info through `Boot HART MEDELEG`, executes the
S-mode handoff — then a **silent, recurring trap**. No `sbi_trap_error` dump
(OpenSBI *redirects* the fault to S-mode rather than printing it), so the cause was
unknown.

## Simulation approach

The NOEL-V-only testbench (`tb_noelvsys_only`) runs the core against `ahb_bram`
(byte-writes + LR/SC both work), so it looks *past* the `ahb2wb_bridge` bugs the
cache fix targets and exposes the shim's intrinsic behaviour, with a full
retired-instruction trace (`disas=1`).

- `//boards/noelv/tool.vivado:opensbi_trace_fuchsia` — full OpenSBI + the real shim.
- `//bin/noelv_shim_handoff` + `:shim_fault_trace` — a minimal M-mode stub that
  reproduces OpenSBI's handoff and `mret`s straight into the shim at `0x240000`
  (reusing the image), bypassing the too-slow-to-simulate full OpenSBI boot. Its
  `m_trap` latches the first fault's `mcause`/`mepc`/`mtval` into `s0`/`s1`/`s2`.

## Findings

1. **OpenSBI boots past the old `sbi_hart_hang`.** The byte-strobe, timebase,
   LR/SC-free `atomic_cmpxchg`, and M-UART-region fixes all work in sim. (The full
   boot is too FDT/UART-heavy to simulate all the way to the handoff — tens-to-
   hundreds of ms of sim time — hence the bypass stub.)

2. **The shim's code is healthy.** Entered in **M-mode** (which bypasses PMP), the
   shim executes **1912 unique PCs cleanly**, from `0x240000` to ~`0x26e0xx`
   (~188 KB in), **no fault**. So the recurring trap is *not* a code/instruction bug.

3. **The fault is purely an S-mode privilege issue.** Entered in **S-mode**, the
   shim can't even *fetch* `0x240000` — instruction access fault (`mcause=1`,
   `mtval=0x240000`) on the very first instruction. Tried and did *not* fix it:
   no PMP, unlocked NAPOT (all-ones and fitted), **locked** NAPOT, and clearing
   `mseccfg` (Smepmp MML). A minimal stub cannot reproduce whatever grants S-mode
   execute on this core.

4. **This matches the HW symptom.** The silent post-MEDELEG recurring trap is
   consistent with the shim being **unable to start in S-mode**: its first fetch at
   `0x240000` takes an access fault → not delegated (`medeleg` bit 1 clear) → M →
   OpenSBI redirects it to S-mode (`stvec` still 0) → fetch at 0 faults → loop.
   Silent, recurring — exactly log42.

## Likely root cause

**S-mode instruction execute at the DDR3/low-RAM region is not being granted** on
this NOEL-V. Either (a) the real fault — the core/OpenSBI PMP (or a PMA marking the
DDR3 region non-S-executable, or a Smepmp detail) denies S-mode execute, so *any* OS
payload can't start; or (b) a stub-fidelity gap — OpenSBI grants it on HW via a
setup the minimal stub doesn't replicate, and the HW shim faults *later* in S-mode.

## Next step: confirm on hardware

Add a redirect tracer to OpenSBI (reuse the `dbg_bb` raw-UART method from
`coldboot_tracer.patch`) in the trap path, so the recurring trap's `mcause`/`sepc`
are bit-banged before OpenSBI redirects. Upload to the cache-fix board:

- `mcause=1` (instruction access fault), `sepc=0x240000` → **(a) confirmed**: the
  platform denies S-mode execute of DDR3. Fix lives in the NOEL-V PMP/PMA config
  and/or OpenSBI's `sbi_hart_pmp_configure` for the catch-all S/U region.
- a different cause/PC → **(b)**: the shim runs in S-mode on HW and faults later;
  fix the stub's S-mode grant and re-diagnose, or read it from the HW trace.

grmon (next debug-module bitstream) would also read `scause`/`sepc` directly.
