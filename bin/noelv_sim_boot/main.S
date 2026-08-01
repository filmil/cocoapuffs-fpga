.section .text
.global _start

# Minimal NOEL-V simulation boot stub.
#
# Used by the OpenSBI bring-up simulation (boards/noelv/tool.vivado:opensbi_trace):
# the testbench pre-loads OpenSBI into the low "DDR3" RAM at 0x40000 (standing in
# for what the SERV ihex uploader does on hardware), and the NOEL-V resets into
# the boot BRAM at 0xC0000000 running this stub.
#
# Unlike the hardware boot stub (//bin/noelv_boot, SIM_FAST=0) this does NOT print
# a banner and has NO UART-drain delay loops (those are ~0x100000 iterations each
# = tens of ms of simulated time, impractical to simulate).  OpenSBI brings up its
# own console, so the stub just sets the RISC-V boot protocol args and jumps:
#   a0 = hartid = 0
#   a1 = 0  -> OpenSBI (fw_payload) falls back to its embedded FDT (fw_fdt_bin)
#   pc = 0x40000  (the pre-loaded OpenSBI fw_payload entry)

#define PAYLOAD 0x40000

_start:
    nop                      # reset alignment buffer
    li   a0, 0
    li   a1, 0
    li   t0, PAYLOAD
    jr   t0
