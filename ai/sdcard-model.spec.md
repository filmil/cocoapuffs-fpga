# Task create a SPI SD card simulation model in vhdl

In directory `//third_party/sdcard`, create a simulation model in VHDL for
a SPI mode SD memory card.

* Read `//GEMINI.md` for general guidance.
* Allow loading SD card content via a text file.
* Use the bazel build approach from other parts of this repository. Specifically
  declare filegroups only in the "main dirs" and create subdirs for tools, such
  as `tool.vivado` for tool specific things.
* Use generics to specify the SD card size.
