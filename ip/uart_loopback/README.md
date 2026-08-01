<!-- SPDX-License-Identifier: Apache-2.0 -->
# A loopback UART that just sends back anything it is given.

# Prerequisites

* Alinx A200T board.
* Vivado hw_server running at localhost:3122. May be remote tunneled.

## Program the device

The command below will build everything, and program the FPGA at the
given `hostport` and `device`.

```
bazel run //ip/uart_loopback:prog  -- \
    --hostport=localhost:3122 \
    --device="*/xilinx_tcf/Digilent/210251130202"
```
