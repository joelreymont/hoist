---
title: Finish Mach-O writer
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.876688+01:00"
blocks:
  - hoist-finish-coff-writer-7776ad8b
---

Context: src/object/macho.zig:159,194; cause: symbol index + load commands/sections TODO; fix: implement load commands, section table, symtab, strtab; deps: none; verification: emit Mach-O and link with ld
