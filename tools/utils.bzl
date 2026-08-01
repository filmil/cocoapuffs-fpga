# SPDX-License-Identifier: Apache-2.0
# See LICENSE file.
# From:
# https://stackoverflow.com/questions/53531405/best-way-to-create-template-file-in-bazel-macro

def _genfile_impl(ctx):
    outfile = ctx.outputs.output
    ctx.actions.expand_template(
        template = ctx.attr.template.files.to_list()[0],
        output = outfile,
        substitutions = {key: ctx.expand_location(value, ctx.attr.data)
            for (key, value) in ctx.attr.substitutions.items()},
    )
    return [
        DefaultInfo(files = depset([outfile])),
    ]

genfile = rule(
    implementation = _genfile_impl,
    attrs = {
        "template": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "output": attr.output(
            mandatory = True,
        ),
        "substitutions": attr.string_dict(),
        "data": attr.label_list(),
    },
)
