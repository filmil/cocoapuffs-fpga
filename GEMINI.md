# Gemini Instructions

Firstly, read `README.md` to understand how to build and what the purpose of
things is.

Never auto-modify the following files:
* //tools/bazel
* Any dotfile.
* Any `*.lock` files.
* Any `*.nix` files.

Unless otherwise instructed, only apply maintenance tasks to files in the git
index, or uncommitted files, to avoid redoing work on files that are already
committed to git.

## General change rules

* Do not change files in `//third_party` without user's explicit permission.
* Remove trailing whitespace from file lines, including at ends of files.

## General git commit rules

* Any git commit created by Gemini must contain this note as the last line in
  the commit message in addition to any commit summaries added:

  ```
  This commit has been created by an automated coding assistant,
  with human supervision.
  ```

* Use "Conventional Commits 1.0.0" as a specification for how to make the
  git commit messages.

* Before creating a pull request for github, pull and rebase the `main` branch
  from origin, to ensure that a PR applies cleanly to the latest top of tree.


## General target creation

* Add source files to BUILD.bazel` filem, in `filegroup` targets.
  * Add a comment `# do not sort` before the `srcs` param of each new `filegroup` target.
  * If you notice a `filegroup` target without a `# do not sort`, add it.
* Add tool-specific build targets to the respective `tool.TOOLNAME`, where
  `TOOLNAME` is the specific name of the tool, such as `tool.vivado`, or
  `tool.nvc`.
* Prefer creating `tool.nvc` if the code created contains only VHDL files.
* If the filegroup contains VHDL files:
  * For each `filegroup` target add tags: `vhdl_ls`, and `vhdl_ls_lib_NAME`,
    where `NAME` is replaced by the name of the library.
* Once targets with source are created, run `bazel run @vhdl_ls_gen//:gen` to
  generate updated `//vhdl_ls.toml`.

## General module creation rules

* Prefer VHDL for writing programmable hardware module code.
  * Prefer `std_ulogic` types to `std_logic` types where there are no
    multiple connections to the same network.
  * Prefer defining procedures for continuous assignment expressions in VHDL.
* Every module must have unit tests.
  * Use VUnit for tests. Consult other directories for examples.
* When documenting modules, use ASCII art to show timing diagrams for some
  typical transactions.
* When referring to text files by file path in code, refer relative to the
  repository root. So for example `foo.txt` in dir `//bar` should be referred
  to as `bar/foo.txt`.

## Documentation

* Use Doxygen rules for documenting.

* Whenever you add Doxygen documentation, also add the source filegroup targets
  , or source files where filegroups are unavailable, to the `srcs` attribute
  of the `doxygen` target named "//:docs", so that doxygen docs could be
  updated too. Include all VHDL files, but also C headers, and any other
  program source files which contain documentation.

* Do not run buildifier, as it will mess up the VHDL file ordering.

* When updating documentation run `bazel build //:docs` to verify that it is
  correct.

## License maintenance

* When maintaining the license files do not modify the following:
  * Files matching `*.gtkw`.
  * Files under the directory `//third_party`.
  * Any files with filenames beginning with a dot.

* For all source files and all BUILD files, verify that they have a license
reference at the beginning of the file.

* If a file does not have a license reference, add the following text in the
  header, appropriately enclosed in comments that are appropriate for the
  source file type in question:

  ```
  SPDX-License-Identifier: Apache-2.0
  ```

## `//third_party` maintenance

* Every subdir under `//third_party` must have a LICENSE file with the
  appropriate license copied from its source distribution.

## Public API documentation maintenance

* Ensure that the repository is clean before starting this procedure.
* For all source files, we want to maintain an up-to-date documentation of
  their respective public API.
* Specific documentation approach instructions:
  * Do not document package bodies in VHDL.
  * Do not document architectures in VHDL.
* With these instructions in mind, find all public API elements in source
  files, and add Doxygen style comments to them.
* When adding documentation for a `@file`, also add a summary of the public API
  elements contained in the respective file, hyperlinking to the referenced API
  elements where possible.
* Once done, create a commit with the created changes, and a commit message
  that contains a summary of changes made, and respects "General git commit
  rules" from above.
* When writing entity documentation, use ASCII art diagrams to document the
  timing diagrams for typical transactions.

