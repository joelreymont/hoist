---
title: Add COFF Section Emission
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.601688+01:00\""
closed-at: "2026-02-05T21:54:37.172490+01:00"
close-reason: COFF section/symtab/strtab/reloc emission is implemented and tested
blocks:
  - hoist-fix-coff-reloc-e80dd588
---

Context: src/object/coff.zig:179; cause: no section/symtab output; fix: emit sections, symtab, strtab, relocations; deps: Fix COFF Reloc Symbol Indices; verification: llvm-readobj --coff
