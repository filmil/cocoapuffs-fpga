# NOEL-V: LR/SC is dead on DDR3, and the OpenSBI S-mode handoff

Follow-on to [debugging-ddr3-byte-write.md](debugging-ddr3-byte-write.md). After
the byte-strobe fix + `timebase-frequency`, OpenSBI boots fully on hardware
(clean banner, full platform/boot-HART info) and then **wedges at the S-mode
handoff** — the payload at `0x240000` never runs.

## Symptom

After `Boot HART MEDELEG …` the console goes silent. The AHB recorder (auto-dump
at ~30 s) shows the core spinning in `atomic_cmpxchg` (`lr.d.aq`/`sc.d.aq`) on a
per-hart scratch field (`scratch+0x90` = `hdata->state`).

## Diagnosis

- OpenSBI printed the *entire* banner + boot info first, so its **spinlocks
  work** — and the firmware disassembly shows `spin_lock` uses `amoadd.w.aqrl`
  (AMO), while there is **exactly one `lr`/`sc` in the whole firmware**:
  `atomic_cmpxchg` (`__sync_val_compare_and_swap`), called by
  `__sbi_hsm_hart_change_state` at the handoff.
- `//bin/noelv_lrsctest` on hardware: **`LRSC BAD 0/1000`** — `sc.d` never
  succeeds; the AMO control (`amoswap.d`) works. `//bin/noelv_clinttest` is
  `OK`, so it isn't a runaway timer trap — `sc.d` itself fails.
- `//boards/noelv/tool.vivado:lrsctest_sim` (the same probe in
  `tb_noelvsys_only`, against behavioral `ahb_bram`): **`sc.d` SUCCEEDS every
  time and the value increments.**

So the core's reservation logic is correct (it works against a plain AHB RAM,
even uncached); **LR/SC reservations are simply not honored on the
DDR3 / `ahb2wb_bridge` path** — there is no AHB exclusive-access monitor. Same
class of bug as the byte strobes: a gap in the bare-AHB DDR3 path, invisible to
the system sim because that sim swaps the bridge out for `ahb_bram`.

This is the *sim-OK / HW-BAD* outcome from the differential-debugging table, and
it localizes the fault to the bridge, not the core/cache.

## Fix applied: LR/SC-free `atomic_cmpxchg` (firmware only)

`third_party/opensbi/single_hart_cmpxchg.patch` replaces
`__sync_val_compare_and_swap` with an M-interrupt-safe read/compare/write:

```c
unsigned long m = csr_read_clear(CSR_MSTATUS, MSTATUS_MIE);
ret = atom->counter;
if (ret == oldval) atom->counter = newval;
if (m & MSTATUS_MIE) csr_set(CSR_MSTATUS, MSTATUS_MIE);
return ret;
```

This is a **single-hart** system, so there are no inter-hart races, and OpenSBI's
other atomics already use AMO. The built firmware now contains **0 `lr`/`sc`
instructions** — so this needs **no bitstream rebuild**, only a firmware
re-upload.

## Proper hardware fixes (alternatives, not applied)

Either would make real LR/SC work and let stock OpenSBI run unpatched:

1. **Make DDR3 cacheable.** Enable the NOEL-V L1 D-cache and mark the DDR3 region
   cacheable (the `noelvsys` `cached` mask). LR/SC reservations then live in the
   L1 line and `sc.d` hits the cache, never reaching the bridge. Caveats: device
   regions (UART `0xFF900000`, CLINT `0xE0000000`, boot BRAM `0xC0000000`) must
   stay **uncached**, and the SERV→NOEL-V handoff needs cache invalidate/flush so
   the core doesn't read stale firmware/payload the SERV just wrote to DDR3 (cold
   cache at boot makes this mostly moot). Requires a bitstream rebuild.
2. **Add an AHB exclusive-access monitor** to `ahb2wb_bridge` so `sc.d`'s
   exclusive store is tracked across the bridge. More invasive; needs the
   NOEL-V's LR/SC bus protocol details.

The cache route (1) is the cleaner "real" fix and is recommended if the workaround
proves insufficient or a multi-hart config is ever needed.
