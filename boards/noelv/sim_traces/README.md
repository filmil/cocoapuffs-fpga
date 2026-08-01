# NOEL-V OpenSBI boot — preserved RTL-simulation trace

Ground-truth instruction + bus trace from booting OpenSBI on the NOEL-V GP core
in `//boards/noelv/tool.vivado:opensbi_trace` (NOEL-V-only testbench, behavioral
BRAM matching the HW memory map, OpenSBI pre-loaded at 0x40000). Captured so the
sim can be correlated against on-hardware AHB-recorder dumps.

**Result of this run:** OpenSBI boots cleanly — `fw_platform_init` →
`sbi_domain_init` → `sbi_hsm_init` → `sbi_platform_early_init` →
**`sbi_hart_init` @ 7.43 ms** → prints a clean `OpenSBI v1.6` banner (see
`opensbi_banner.txt`). No hang, no wedge. The firmware is correct; the HW failure
is HW-specific (UART path), not the firmware.

## Files

| file | what |
|------|------|
| `opensbi_boot_trace.log.gz` | full sim stdout: NOEL-V `disas` instruction trace + AHB monitor + UART writes (81 MB raw). `zcat` it. |
| `opensbi_pc_trace.txt.gz`   | compact one-line-per-instruction: `<ns> <PC> <opcode> <disasm>` |
| `opensbi_ahb_trace.txt.gz`  | AHB-bus transactions only (`AHBMON ...`) — the direct analog of the HW AHB recorder |
| `opensbi_milestones.txt`    | function-level call sequence (which OpenSBI step ran when) |
| `opensbi_banner.txt`        | the banner OpenSBI wrote to the APBUART, decoded |

## Trace line format (full log)

```
   7434710 ns : C0-0  M : 458123  [1] @0x000000000004c57c (0x...) <disasm>  W[reg=val]  M[memaddr]
   ^time        ^core ^mode ^count    ^PC                 ^opcode            ^reg write  ^mem access
```
- `M[0x00000000ff900000]` + `W[x0=0x..]` on a `sw` = a byte written to the APBUART (the `=0x..` low byte is the char).
- `AHBMON ... REQ RD 0x...` = an instruction-fetch / data request presented on the bus (with `hready`); `RD/WR 0x... hrdata/hwdata=0x..` = the completed data-phase.

## Correlating with the HW AHB recorder

The HW recorder (`//ip/debug`) logs `<cycle> <W|R> <haddr> <hwdata>`. To line it
up with this sim:
- Match the recorder's `haddr` sequence against `opensbi_ahb_trace.txt.gz` (same
  addresses, same order) or `opensbi_pc_trace.txt.gz` (PC = instruction-fetch
  haddr). OpenSBI code lives at 0x40000–0x5f000; data/heap/stack at 0x80000–0x91000.
- Map any PC to an OpenSBI function with the symbol table:
  `bazel build //boards/noelv:disasm` then look up the address in
  `bazel-bin/boards/noelv/opensbi_fw.dis`.
- The relocated FDT is at 0x2240000 (`fw_next_arg1` = `_fw_start`+0x2200000); the
  payload at 0x240000.

## How this was generated

`bazel build //boards/noelv/tool.vivado:opensbi_trace` (xsim, `disas=1`, the
testbench AHB monitor, hang-detection at `sbi_hart_hang`). Two `@opensbi` debug
speedup patches were active so the sim reaches the banner in tractable wall time
(`third_party/opensbi/fdt_assume_perfect.patch`,
`third_party/opensbi/skip_unused_early_scans.patch` — see `MODULE.bazel`). These
do **not** change the boot result; they cut OpenSBI's libfdt walking. The
`skip_unused_early_scans` patch disables the SBI reset/HSM-suspend/CPPC drivers —
revert it for a production firmware.
