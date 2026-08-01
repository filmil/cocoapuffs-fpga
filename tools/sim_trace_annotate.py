#!/usr/bin/env python3
"""Annotate a NOEL-V (grlib disas=1) instruction trace with OpenSBI function
names and print a compressed call-sequence, for the //boards/noelv/tool.vivado:
opensbi_trace simulation.

Usage:
  sim_trace_annotate.py <sim.log> <symbols.txt> [--full] [--watch FN[,FN...]]

symbols.txt: lines of "<hexaddr>\t<name>" (objdump function labels).
Default output: one line per *function transition* (PC enters a new function),
with the instruction count spent in the previous function -- i.e. the boot
call-sequence. --full also prints every instruction, annotated.
--watch prints every instruction inside the named functions (with reg/mem).
"""
import sys, bisect, re

def load_syms(path):
    syms = []
    for line in open(path):
        line = line.rstrip("\n")
        if not line or "\t" not in line:
            continue
        a, n = line.split("\t", 1)
        try:
            syms.append((int(a, 16), n))
        except ValueError:
            pass
    syms.sort()
    return [a for a, _ in syms], [n for _, n in syms]

# disas line, e.g.:
#   99830 ns : C0-1  M : 4985  [1] @0x000000000004007a (0x02e1) addi t0,...  W[...] M[...]
LINE = re.compile(
    r"^\s*(\d+)\s*ns\s*:\s*C0-\d+\s+\S+\s*:\s*(\d+)\s+\[\d+\]\s+@0x([0-9a-f]+)\s+\(0x([0-9a-f]+)\)\s+(.*?)\s*$"
)

def main():
    args = sys.argv[1:]
    full = "--full" in args
    watch = set()
    if "--watch" in args:
        i = args.index("--watch")
        watch = set(args[i + 1].split(","))
        del args[i:i + 2]
    args = [a for a in args if a != "--full"]
    logpath, sympath = args[0], args[1]
    addrs, names = load_syms(sympath)

    def fn(pc):
        i = bisect.bisect_right(addrs, pc) - 1
        return names[i] if i >= 0 else "?"

    cur = None
    count = 0
    first_time = None
    n_instr = 0
    for line in open(logpath, errors="replace"):
        m = LINE.match(line)
        if not m:
            continue
        t_ns, icount, pc_hex, op_hex, dis = m.groups()
        pc = int(pc_hex, 16)
        f = fn(pc)
        n_instr += 1
        if watch and f in watch:
            print(f"  [{t_ns}ns] {f}: @0x{pc_hex[-6:]} ({op_hex}) {dis}")
        if f != cur:
            if cur is not None:
                print(f"{first_time:>10}ns  {cur:<34} x{count}")
            cur = f
            count = 1
            first_time = int(t_ns)
        else:
            count += 1
        if full:
            print(f"    @0x{pc_hex[-6:]} {f:<28} ({op_hex}) {dis}")
    if cur is not None:
        print(f"{first_time:>10}ns  {cur:<34} x{count}")
    print(f"# total instructions traced: {n_instr}", file=sys.stderr)

if __name__ == "__main__":
    main()
