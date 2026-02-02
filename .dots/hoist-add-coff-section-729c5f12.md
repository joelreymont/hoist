---
title: Add COFF Section Emission
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.601688+01:00"
blocks:
  - hoist-fix-coff-reloc-e80dd588
---

Context: src/object/coff.zig:179; cause: no section/symtab output; fix: emit sections, symtab, strtab, relocations; deps: Fix COFF Reloc Symbol Indices; verification: llvm-readobj --coff
