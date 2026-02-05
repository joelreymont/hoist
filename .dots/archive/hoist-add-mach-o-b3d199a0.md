---
title: Add Mach-O Section Emission
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.615504+01:00\""
closed-at: "2026-02-05T21:54:48.700324+01:00"
close-reason: Mach-O segment/section/symtab/reloc emission is implemented and tested
blocks:
  - hoist-fix-mach-o-e88db236
---

Context: src/object/macho.zig:179; cause: no load commands/sections/symtab; fix: emit LC_SEGMENT_64, symtab, strtab, relocs; deps: Fix Mach-O Reloc Symbol Indices; verification: otool -l + nm
