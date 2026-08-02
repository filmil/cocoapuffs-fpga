<!-- SPDX-License-Identifier: Apache-2.0 -->
# Cocoapuffs: a NOEL-V RISC-V SoC on an Artix-7 FPGA that boots Zircon

[![Build](https://github.com/filmil/cocoapuffs-fpga/actions/workflows/build.yml/badge.svg)](https://github.com/filmil/cocoapuffs-fpga/actions/workflows/build.yml)

**Cocoapuffs** is a homebrew RISC-V system-on-chip for the Alinx AX7A200B board
(AMD Artix-7 `xc7a200t`), built entirely with [Bazel][bazel] and open tooling.
Its main core is the 64-bit [NOEL-V][noelv] (from the [GRLIB][grlib] IP library);
a small bit-serial [SERV][serv] RV32 core acts as the serial boot loader, backed
by DDR3, a Gaisler APBUART, and the usual GRLIB plumbing.

On this SoC, Google Fuchsia's **[Zircon][zircon] microkernel boots end to end** —
OpenSBI (M-mode) → `linux-riscv64-boot-shim` → physload/physboot → the Zircon
kernel's full init → userspace/userboot — with an interrupt-driven serial
console. As far as we know this is the first Fuchsia boot on this kind of
homebrew programmable hardware.

The full story is written up here:

- **Blog post:** [Booting Zircon on a homebrew RISC-V SoC][post]
- **Technical report (PDF):** [the complete bring-up write-up][paper]

## The boot chain

```
SERV ihex loader ──▶ OpenSBI (M-mode) ──▶ linux-riscv64-boot-shim
      ──▶ physload ──▶ physboot ──▶ Zircon kernel ──▶ userboot (userspace)
```

The board carries no boot ROM: the SERV core receives a firmware image over the
serial line as Intel HEX, streams it into DRAM, then releases the NOEL-V to run
it. Every experiment is an image streamed to the SERV loader and launched on the
NOEL-V.

## Prerequisites

- **Hardware:** an Alinx AX7A200B (Artix-7 `xc7a200t`) board. Simulation targets
  need no hardware.
- **Bazel** — via [bazelisk][bazelisk]; the pinned version is in `.bazelversion`.
- **Xilinx Vivado** — for synthesis, place-and-route, and programming. A Vivado
  `hw_server` must be reachable for programming (default `localhost:3122`; it may
  be tunnelled from a remote host).
- The RISC-V GCC toolchain, GHDL/NVC (VHDL simulation), and a C++/Go toolchain
  are all fetched hermetically by Bazel — nothing to install by hand.

## Build

Everything (RTL, firmware, tools, docs) builds through Bazel:

```bash
bazel build //...
```

Key artifacts:

```bash
# FPGA bitstream (synthesis + place-and-route; ~1.5 h for the HP NOEL-V core)
bazel build //boards/noelv/tool.vivado:pnr

# Zircon boot image: OpenSBI + boot-shim + the Zircon ZBI, as one Intel-HEX
# -> bazel-bin/boards/noelv/opensbi_fw_zircon.hex
bazel build //boards/noelv:opensbi_fw_zircon_hex
```

## Program the FPGA

With a Vivado `hw_server` reachable at `--hostport`, this builds the bitstream
(`:pnr`) and programs the board:

```bash
bazel run //boards/noelv/tool.vivado:prog -- \
    --hostport=localhost:3122 \
    --device="*/xilinx_tcf/Digilent/<your-board-serial>"
```

## Boot Zircon on the board

Once the FPGA is programmed, the on-chip SERV core runs an Intel-HEX loader.
Stream the boot image to it over the serial port:

```bash
bazel run //third_party/futility:upload -- \
    --remote-timeout=1800 -- -- \
    --device=/dev/ttyUSB0 \
    --file=boards/noelv/opensbi_fw_zircon.hex \
    --prompt='ihex:' --line-buffer --linger
```

`--device` is your board's serial port. The combined image is ~6 MB, so the
upload takes roughly 25 minutes. Then watch the **same serial port at 115200
baud**: OpenSBI's banner, the boot shim, physboot, the Zircon kernel's init, and
userspace scroll by, ending at the expected no-`bootfs` terminus for the "eng"
ZBI.

## Run it in simulation (no board)

The whole boot can be reproduced in the RTL simulator against a faithful ZBI
image — no hardware needed:

```bash
# Full OpenSBI -> shim -> physboot -> Zircon boot in xsim
bazel build //boards/noelv/tool.vivado:zircon_full_boot

# Lighter checks:
bazel build //boards/noelv/tool.vivado:sim              # NOEL-V "halt." sanity
bazel build //boards/noelv/tool.vivado:opensbi_trace_zircon  # OpenSBI+shim trace
```

## Directory Structure

The project is organized into the following key directories:

*   **`//` (Root)**: Main configuration files like `README.md`, `LICENSE`, and the
    Bazel build files (`MODULE.bazel`, `.bazelrc`, `.bazelversion`).
*   **`//.github`**: GitHub Actions workflows for Continuous Integration (CI)
    (e.g., `workflows/build.yml`).
*   **`//boards`**: Board-level top designs. `noelv` is the Cocoapuffs NOEL-V SoC
    (RTL wiring, `board.dts`, the OpenSBI/Zircon firmware genrules, and the
    NVC/Vivado simulation targets); `rv32_uart`, `rv32_ddr3`, and `rv32_ddr3exec`
    are the earlier SERV RV32 bring-up boards.
*   **`//bin`**: RISC-V test and boot programs (`noelv_*`, `rv32_*`,
    `opensbi_hello`).
*   **`//lib`**: Shared C firmware support (UART, timer, PIC, ihex, memtest).
*   **`//doc`**: Project documentation. Key documents include:
    *   `testing.md`: Information on running simulations and tests.
    *   `bus_naming_style.md`: Guidelines for bus signal naming.
    *   `using_xilinx_components.md`: Notes on using Xilinx IP and primitives.
*   **`//ip`**: The Register Transfer Level (RTL) VHDL code for the hardware
    Intellectual Property (IP) cores. This is the heart of the hardware design.
    Notable subdirectories include:
    *   `a200t`: Components specific to the Alinx A200T board (e.g., clock
        generators `clkgen.vhdl`, `clkgen_complex.vhdl`; board-level entity
        `board.ent.vhdl`; RAM `ram.vhdl`; UART `uart.vhdl`).
    *   `axi`: AXI (Advanced eXtensible Interface) bus components (e.g.,
        `host.pkg.vhdl`, `per.pkg.vhdl`).
    *   `bridges`: AXI/AHB bridge IP.
    *   `ddr3`: DDR3 SDRAM controller and PHY components (e.g., `phy.pkg.vhdl`,
        `cfg.pkg.vhdl`).
    *   `debug`: An AHB debug/trace recorder.
    *   `plic`: The RISC-V platform-level interrupt controller (PLIC).
    *   `tl`: TileLink bus components.
    *   `wb`: Wishbone bus components (e.g., `host.pkg.vhdl`, `per.pkg.vhdl`,
        `signals.pkg.vhdl`).
    *   `wb_uart`: A UART component with a Wishbone interface (`wb_uart.ent.vhdl`).
    *   `xilinx`: Wrappers or models for Xilinx-specific primitives
        (`xilinx.vhdl`).
*   **`//testing`**: Simulation models, testbenches, and testing utilities,
    including the NVC/Vivado/GHDL harnesses.
*   **`//third_party`**: Vendored external open-source code -- GRLIB, the SERV
    RISC-V core, OpenSBI, the Fuchsia boot artifacts, VUnit/OSVVM, the RISC-V
    toolchain, and the Bazel rule shims.
*   **`//tools`**: Build and utility programs (e.g., `bintomemh`, which converts a
    binary to Verilog `memh` format).

## Key Components

This repository provides a collection of VHDL IP cores and example designs. Some
of the key components include:

*   **NOEL-V SoC (`//boards/noelv`)**: The Cocoapuffs system-on-chip -- a 64-bit
    GRLIB NOEL-V core with a SERV RV32 serial boot loader, DDR3, and an APBUART --
    that boots Zircon.
*   **Alinx A200T Board Support (`//ip/a200t`)**:
    *   `clkgen`: Clock generation and management modules tailored for the A200T
        (e.g., `clkgen.vhdl`, `clkgen_complex.vhdl`).
    *   `ram`: Example of utilizing on-board RAM (`ram.vhdl`).
    *   `uart`: Basic UART communication specific to the board's connections
        (`uart.vhdl`).
*   **AXI Interconnect (`//ip/axi`)**: A collection of modules for building
    systems based on the AXI protocol, including host (`host.pkg.vhdl`) and
    peripheral (`per.pkg.vhdl`) components.
*   **DDR3 Memory Interface (`//ip/ddr3`)**: Components for interfacing with DDR3
    SDRAM. Includes PHY (`phy.pkg.vhdl`) and configuration (`cfg.pkg.vhdl`)
    packages.
*   **Wishbone Interconnect (`//ip/wb`)**: Modules for the Wishbone bus
    architecture, a lightweight and simple bus protocol (e.g., `host.pkg.vhdl`,
    `per.pkg.vhdl`).
*   **UART Cores**:
    *   `//ip/wb_uart`: A UART core with a Wishbone interface (`wb_uart.ent.vhdl`).
    *   A general UART core is also available via `//third_party/uart`.
*   **RISC-V Example System (`//boards/rv32_uart`)**: A minimal System-on-Chip
    (SoC) demonstrating the integration of the "serv" RISC-V core (from
    `//third_party/serv`) with a UART peripheral via a Wishbone bus, useful as a
    starting point for custom SoC designs.
*   **Xilinx Specific Utilities (`//ip/xilinx`)**: Wrappers and utilities for
    leveraging Xilinx-specific FPGA features and primitives (`xilinx.vhdl`).

Refer to the `//ip` directory and specific component subdirectories for more
detailed information and RTL code.

## Examples

The repository includes several examples to help you get started with using and
integrating the IP cores:

*   **NOEL-V + Zircon (`//boards/noelv`)**: The full Cocoapuffs SoC that boots
    Fuchsia's Zircon -- see the Build / Program / Boot sections above.
*   **RISC-V UART System (`//boards/rv32_uart`)**: A minimal SoC featuring the
    "serv" RISC-V core connected to a UART peripheral via a Wishbone bus. It
    includes the RTL for the system, a testbench, and basic software to run on the
    RISC-V core -- excellent for understanding how to build a simple SoC with the
    provided components.
*   **UART Loopback (`//ip/uart_loopback`)**: A simple UART loopback, useful for
    basic UART testing on the Alinx A200T board. It includes the VHDL top-level
    for the board and the necessary constraints. For more details, see the
    [UART Loopback README](ip/uart_loopback/README.md).

## License

Apache License, Version 2.0. See [LICENSE](LICENSE).

[bazel]: https://bazel.build
[bazelisk]: https://github.com/bazelbuild/bazelisk
[noelv]: https://www.gaisler.com/index.php/products/processors/noel-v
[grlib]: https://www.gaisler.com/grlib-ip-library
[serv]: https://github.com/olofk/serv
[zircon]: https://fuchsia.dev/fuchsia-src/concepts/kernel
[post]: https://hdlfactory.com/post/2026/07/19/cocoapuffs-booting-fuchsias-zircon-kernel-on-a-risc-v-core-in-artix-7-fpga/
[paper]: https://hdlfactory.com/a200t/zircon_noelv_interrupt_console.html
