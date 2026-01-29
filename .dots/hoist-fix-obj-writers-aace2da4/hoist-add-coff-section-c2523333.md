---
title: Add COFF Section Emission
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.479850+01:00"
---

Context: src/object/coff.zig:179; cause: no section/symtab output; fix: emit sections, symtab, strtab, relocations; deps: hoist-fix-coff-reloc-817807ae; verification: llvm-readobj --coff
