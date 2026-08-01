/* SPDX-License-Identifier: Apache-2.0 */
/*
 * Relocation trampoline for booting Zircon: the NOEL-V boot stub
 * (//bin/noelv_boot) hard-jumps to 0x40000 (hardcoded in the bitstream BRAM),
 * but Zircon physboot relocates the kernel into low RAM and overwrites OpenSBI
 * if OpenSBI lives at 0x40000.  This 2-instruction stub is what the boot stub
 * jumps to at 0x40000; it immediately jumps to OpenSBI relocated HIGH (0x3D000000,
 * out of the kernel's low-RAM relocation path).  a0=hartid, a1=fdt(0) are passed
 * through untouched (RISC-V SBI boot protocol).  When physboot later overwrites
 * 0x40000 with the kernel, this stub is long gone -- OpenSBI is already running
 * at 0x3D000000.  Linked at 0x40000.
 */
.section .text
.global _start
_start:
    lui  t0, 0x3d000       /* t0 = 0x3D000000 (relocated OpenSBI text_start) */
    jr   t0
