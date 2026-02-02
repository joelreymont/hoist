---
title: Add Mach-O Section Emission
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.615504+01:00"
blocks:
  - hoist-fix-mach-o-e88db236
---

Context: src/object/macho.zig:179; cause: no load commands/sections/symtab; fix: emit LC_SEGMENT_64, symtab, strtab, relocs; deps: Fix Mach-O Reloc Symbol Indices; verification: otool -l + nm
