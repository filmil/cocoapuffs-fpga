# Task: Implement TL-C

## Prerequisites

* Read `//local/GEMINI.md` for general instructions.
* Read `//README.md` for build behavior.

## Subtasks

### Subtask 1

Implement the TL-C converter to wblite.

* Start measuring the time for the implementation task.
* When adding API elements, always document them. Use doxygen syntax, and `--!`
  as the doxygen comment prefix.

* Implement the entity converter in //ip/tl
* Implement the vunit test fixture in //testing for TL-C
* Implement the unit tests for TL-C
  * Single reads
  * Operations
  * Bursts from 4b to 64b, reads and writes.
* Reformat all files to 80 columns, to language-specific conventions.
* Report elapsed time for the task.
