<!-- SPDX-License-Identifier: Apache-2.0 -->
# Components for the Alinx A200T board

[![Build](https://github.com/filmil/a200t_examples/actions/workflows/build.yml/badge.svg)](https://github.com/filmil/a200t_examples/actions/workflows/build.yml)

This repository contains example circuitry definitions used for the turn-up
of the Alinx A200T board.  The code as well as documentation itself, are all
work in progress, but there's already a little bit there.

Unfortunately, the board does *not* come with boards-specific source code so I am
trying to develop that board specific code here.

The idea is to build out the following:

- Simulation models for *all* the peripheral devices available on the Alinx
  A200T board.
- RTL models for the controllers for *all* the peripheral devices available on the
  board.

## Project Status

This project is actively under development, aiming to provide a comprehensive set of open-source hardware components and examples for the Alinx A200T board. While many parts are still a work in progress, several key areas have seen significant development:

*   **Basic Board Peripherals:** Initial implementations for core peripherals like clock generation (`clkgen`), on-board RAM, and UART are available.
*   **Memory Controllers:** Work has begun on DDR3 memory controller logic.
*   **Interconnects:** AXI interconnect components are being developed.
*   **Example Systems:** A RISC-V based UART example (`rv32_uart`) is included to demonstrate a simple System-on-Chip.

Future work will focus on expanding the peripheral set, improving existing modules, adding more comprehensive documentation, and providing more example designs.

## Getting Started

This section guides you through setting up your environment and running your first designs with this repository.

### Prerequisites

*   **Hardware:**
    *   Alinx A200T FPGA board (or a compatible Artix-7 FPGA for some generic modules).
*   **Software:**
    *   Xilinx Vivado (for synthesis, implementation, and Xilinx IP integration). Refer to [doc/using_xilinx_components.md](doc/using_xilinx_components.md).
    *   Bazel (for building the project). You can find Bazel build files (`BUILD.bazel`, `WORKSPACE`) throughout the repository.
    *   GHDL and/or NVC (for VHDL simulation). Evidence of their use can be found in `ip/rv32_uart/ghdl` and `ip/wb/tool.nvc` respectively. Refer to `doc/testing.md` for more details on simulation.
    *   A C++ compiler (e.g., GCC) and Go programming language environment are required for some software tools and testbench components (e.g., `tools/bintomemh/main.go`, `ip/rv32_uart/main.cc`).

### Building the Project

The project uses Bazel as the primary build system. To build all targets, you can typically run:
```bash
bazel build //...
```
Specific targets can be built by specifying their path, e.g., `bazel build //ip/a200t:clkgen_complex`.

### Simulation and Testing

Simulation is crucial for verifying the HDL designs.
*   Detailed instructions for running simulations and tests can be found in [doc/testing.md](doc/testing.md).
*   Testbenches are generally located in the `//testing` directory and within individual IP core directories (e.g., `//ip/a200t/clkgen_complex.test.vhdl`, `//testing/uart/uart_loopback_test.vhdl`).

### Synthesis and Implementation

For deploying designs to the FPGA:
*   Xilinx Vivado is the recommended tool for synthesis and implementation.
*   Guidance on using Xilinx components can be found in [doc/using_xilinx_components.md](doc/using_xilinx_components.md).
*   Board-specific constraints (pin assignments, timings) are provided in `.xdc` files (e.g., `ip/a200t/a200t.xdc`).

## Directory Structure

The project is organized into the following key directories:

*   **`//` (Root)**: Contains main configuration files like `README.md`, `LICENSE`, Bazel build system files (`WORKSPACE`, `MODULE.bazel`, `deps.bzl`, `.bazelrc`, `.bazelversion`), and `flake.nix` for Nix environment.
*   **`//.github`**: Houses GitHub Actions workflows for Continuous Integration (CI) and other automation (e.g., `workflows/build.yml`).
*   **`//doc`**: Contains project documentation. Key documents include:
    *   `testing.md`: Information on running simulations and tests.
    *   `bus_naming_style.md`: Guidelines for bus signal naming.
    *   `using_xilinx_components.md`: Notes on using Xilinx IP and primitives.
*   **`//ip`**: Contains the Register Transfer Level (RTL) VHDL code for various hardware Intellectual Property (IP) cores. This is the heart of the hardware design. Notable subdirectories include:
    *   `a200t`: Components specific to the Alinx A200T board (e.g., clock generators `clkgen.vhdl`, `clkgen_complex.vhdl`; board-level entity `board.ent.vhdl`; RAM `ram.vhdl`; UART `uart.vhdl`).
    *   `axi`: AXI (Advanced eXtensible Interface) bus components (e.g., `host.pkg.vhdl`, `per.pkg.vhdl`).
    *   `ddr3`: DDR3 SDRAM controller and PHY components (e.g., `phy.pkg.vhdl`, `cfg.pkg.vhdl`).
    *   `rv32_uart`: An example system with a RISC-V core and UART, including its own software (`software/main.cc`) and testbench (`tb.vhdl`).
    *   `wb`: Wishbone bus components (e.g., `host.pkg.vhdl`, `per.pkg.vhdl`, `signals.pkg.vhdl`).
    *   `wb_uart`: A UART component with a Wishbone interface (`wb_uart.ent.vhdl`).
    *   `xilinx`: Wrappers or models for Xilinx-specific primitives (`xilinx.vhdl`).
*   **`//testing`**: Provides simulation models, testbenches, and testing utilities.
    *   `a200t`: Testbenches and simulation setups specifically for the A200T board environment (e.g., `a200t_clk.vhdl`, `a200t_ddr3.sv`).
    *   `ghdl` (`//testing/ghdl`): Contains test setups and files specific to the GHDL simulator.
        *   `nvc` (`//testing/ghdl/nvc`): Holds configurations or components specifically for use with NVC (which can be used alongside GHDL or as a separate VHDL analysis tool).
    *   `unisim`: Fake Unisim models for simulation (`fake_unisim.pkg.vhdl`).
    *   Shared packages like `asserts.pkg.vhdl` and `wb_tb.pkg.vhdl`.
*   **`//third_party`**: Includes external open-source code, such as:
    *   `core_ddr3_controller`: A DDR3 memory controller.
    *   `nvc`: The NVC VHDL compiler/simulator.
    *   `serv`: The "serv" RISC-V CPU core.
    *   `uart`: A UART IP core.
    *   `riscv32_toolchain`: GCC-based toolchain for RISC-V.
*   **`//tools`**: Contains build and utility scripts and programs.
    *   `bintomemh`: A tool to convert binary files to memory hex format (`main.go`).
    *   `vcd`: Tools for VCD (Value Change Dump) waveform files (`main.go`).
    *   `bazel`: Bazel-related utility scripts.

This structure helps separate design code (`//ip`), testing infrastructure (`//testing`), documentation (`//doc`), and external dependencies (`//third_party`).

## Key Components

This repository provides a collection of VHDL IP cores and example designs. Some of an key components include:

*   **Alinx A200T Board Support (`//ip/a200t`)**:
    *   `clkgen`: Clock generation and management modules tailored for the A200T (e.g., `clkgen.vhdl`, `clkgen_complex.vhdl`).
    *   `ram`: Example of utilizing on-board RAM (`ram.vhdl`).
    *   `uart`: Basic UART communication specific to the board's connections (`uart.vhdl`).
*   **AXI Interconnect (`//ip/axi`)**: A collection of modules for building systems based on the AXI protocol, including host (`host.pkg.vhdl`) and peripheral (`per.pkg.vhdl`) components.
*   **DDR3 Memory Interface (`//ip/ddr3` and `//third_party/core_ddr3_controller`)**: Components and third-party IP for interfacing with DDR3 SDRAM. Includes PHY (`phy.pkg.vhdl`) and configuration (`cfg.pkg.vhdl`) packages.
*   **Wishbone Interconnect (`//ip/wb`)**: Modules for Wishbone bus architecture, a lightweight and simple bus protocol (e.g., `host.pkg.vhdl`, `per.pkg.vhdl`).
*   **UART Cores**:
    *   `//ip/wb_uart`: A UART core with a Wishbone interface (`wb_uart.ent.vhdl`).
    *   A general UART core is also available via `//third_party/uart`.
*   **RISC-V Example System (`//ip/rv32_uart`)**: A minimal System-on-Chip (SoC) demonstrating the integration of the "serv" RISC-V core (from `//third_party/serv`) with a UART peripheral, useful as a starting point for custom SoC designs. Includes RTL (`rv32_uart.entity.vhdl`), testbench (`tb.vhdl`), and example software (`software/main.cc`).
*   **Xilinx Specific Utilities (`//ip/xilinx`)**: Wrappers and utilities for leveraging Xilinx-specific FPGA features and primitives (`xilinx.vhdl`).

Refer to the `//ip` directory and specific component subdirectories for more detailed information and RTL code.

## Examples

The repository includes several examples to help you get started with using and integrating the IP cores:

*   **RISC-V UART System (`//ip/rv32_uart`)**:
    This is a minimal System-on-Chip (SoC) featuring the "serv" RISC-V core connected to a UART peripheral via a Wishbone bus. It includes the RTL for the system, a testbench, and basic software to run on the RISC-V core. This example is excellent for understanding how to build a simple SoC with the provided components. See the `//ip/rv32_uart` directory for all files.

*   **UART Loopback (`//ip/uart_loopback`)**:
    This example demonstrates a simple UART loopback functionality, useful for basic UART testing on the Alinx A200T board. It includes the VHDL top-level for the board and necessary constraints. For more details, see the [UART Loopback README](ip/uart_loopback/README.md).

These examples can serve as templates for your own projects or as demonstrations of how to utilize the IP cores provided in this repository.

## Contributing

Contributions to this project are welcome! If you have improvements, bug fixes, or new features you'd like to share, please follow these general steps:

1.  **Fork the repository.**
2.  **Create a new branch** for your feature or bug fix: `git checkout -b my-new-feature`.
3.  **Make your changes.**
4.  **Test your changes thoroughly.** (Refer to the simulation and testing guidelines in `doc/testing.md`).
5.  **Commit your changes** with a clear and descriptive commit message.
6.  **Push to your fork** and then **submit a pull request** to the main repository.

If you find any issues or have suggestions, please feel free to open an issue on the GitHub repository.

## License

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for the full license text.
