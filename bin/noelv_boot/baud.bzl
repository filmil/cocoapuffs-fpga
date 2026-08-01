# SPDX-License-Identifier: Apache-2.0
"""Configuration transition for the NOEL-V boot UART baud mode.

`boot_in_mode` builds a target (e.g. `:memh` / `:disasm`) with the
`//bin/noelv_boot:uart_mode` build setting pinned to "sim" or "hw", via a
configuration transition. This lets a single `bazel build` produce both the
fast-simulation image and the realistic 115200 bps image, independent of the
global `--//bin/noelv_boot:uart_mode` flag.
"""

def _uart_mode_transition_impl(settings, attr):
    _ = settings  # unused
    return {"//bin/noelv_boot:uart_mode": attr.uart_mode}

_uart_mode_transition = transition(
    implementation = _uart_mode_transition_impl,
    inputs = [],
    outputs = ["//bin/noelv_boot:uart_mode"],
)

def _boot_in_mode_impl(ctx):
    # ctx.files.dep holds the transitioned dependency's default outputs.
    return [DefaultInfo(files = depset(ctx.files.dep))]

boot_in_mode = rule(
    implementation = _boot_in_mode_impl,
    doc = "Build `dep` with the boot UART baud mode pinned via a transition.",
    attrs = {
        "dep": attr.label(
            mandatory = True,
            cfg = _uart_mode_transition,
            doc = "Target to build in the chosen mode (e.g. //bin/noelv_boot:memh).",
        ),
        "uart_mode": attr.string(
            default = "hw",
            values = ["sim", "hw"],
            doc = "'sim' = fast simulation baud, 'hw' = realistic 115200 bps.",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
