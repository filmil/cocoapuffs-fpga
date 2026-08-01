
def hex_file(name, srcs, **kw):
    native.genrule(
        name=name,
        srcs=srcs,
        outs=["{}.hex".format(name)],
        cmd = "$(execpath @riscv_none_elf//:objcopy) -O ihex $< $@",
        tools = ["@riscv_none_elf//:objcopy"],
        **kw,
    )

def bin_file(name, srcs, **kw):
    native.genrule(
        name=name,
        srcs=srcs,
        outs=["{}.bin".format(name)],
        cmd="$(execpath @riscv_none_elf//:objcopy) -O binary $< $@",
        tools=["@riscv_none_elf//:objcopy"],
        **kw
    )

def disasm_file(name, srcs, **kw):
    native.genrule(
        name=name,
        srcs=srcs,
        outs=["{}.S".format(name)],
        cmd="$(execpath @riscv_none_elf//:objdump) -D $< > $@",
        tools=["@riscv_none_elf//:objdump"],
        **kw
    )

def memh_file(name, srcs, args=[], **kw):
    native.genrule(
        name=name,
        srcs=srcs,
        outs=["{}.mem".format(name)],
        cmd="$(execpath //tools/bintomemh) {args} < $< > $@".format(args=" ".join(args)),
        tools=["//tools/bintomemh"],
        **kw
    )
