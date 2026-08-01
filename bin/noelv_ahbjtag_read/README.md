# noelv_ahbjtag_read — openocd AHB reader/writer over the GRLIB ahbjtag

A license-free alternative to GRMON for poking the NOEL-V AHB bus over JTAG.
GRMON's *eval* build refuses this design (it contains the non-GPL NOEL-V core and
demands a professional license). This drives the GRLIB `ahbjtag` debug master
directly from `openocd`, which is GPL and already installed on the JTAG host.

## Use

On the JTAG host (the machine with the Digilent/FT232H cable), with the FPGA
programmed with a bitstream that instantiates `ahbjtag` (see
`//boards/noelv/tool.vivado:pnr`):

```
openocd -f ahb_read.cfg -c "ahb_dump 0xfffff000 8; shutdown"
openocd -f ahb_read.cfg -c "ahb_write 0x03f00000 0xdeadbeef; ahb_dump 0x03f00000 1; shutdown"
```

- `ahb_read addr`            -> 0x-prefixed word
- `ahb_dump addr nwords`     -> labelled hex dump
- `ahb_write addr data [sz]` -> sz: 2=word(default) 1=half 0=byte. For sub-word
  writes the data byte/half must sit on its natural lane (e.g. byte @off1 = 0xNN00).

## Protocol (GRLIB ahbjtag, versel=1 / jtagcom2), from grlib jtagcom2.vhd

The Xilinx BSCANE2 exposes two user JTAG instructions wired to the ahbjtag:

- USER1 (IR `0x02`) = address/command register, 35 bits:
  `{ write[34], hsize[33:32], addr[31:0] }`
- USER2 (IR `0x03`) = data register, 33 bits: `{ seq[32], data[31:0] }`

A read = scan USER1 with `{0, 2, addr}` (the ahbjtag runs the AHB read), then
scan USER2 to capture `data[31:0]`. A write = scan USER1 `{1, size, addr}` then
scan USER2 with the write data.

GRMON's connect equivalent (once a pro license is available):
`grmon -digilent -jtagcomver 1 -endian little`

## IMPORTANT caveat: D-cache coherency

The ahbjtag is a plain AHB master: its reads/writes go to RAM and **bypass the
NOEL-V write-back D-cache**. So:

- Reads of memory the CPU has dirty in cache return **stale RAM**, not the CPU's
  current value. (A reset-device list node read as self-pointing while the head
  read correct — almost certainly a dirty-line artifact, not a real bug.)
- Writes to such memory will be **clobbered** when the CPU later evicts its line.

This reader is therefore reliable for **uncached / raw-hardware** state
(peripherals, plug&play, raw DRAM tests) but NOT for the CPU's live cached data
structures. For coherent reads + PC/halt/step, use the RISC-V debug module or
GRMON professional.

## Confirmed with this tool

- ahbjtag read+write proven working (plug&play vendor IDs read correctly; memory
  written and read back).
- DDR3 (`memory@0`, 0x0–0x3FFFFFFF) sub-word byte writes via the AHB→DDR3 bridge
  work correctly (strobes + lanes), e.g. at 0x03f00000.
