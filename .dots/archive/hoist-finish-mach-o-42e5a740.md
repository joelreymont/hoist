---
title: Finish Mach-O writer
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.876688+01:00\""
closed-at: "2026-02-05T21:54:48.706526+01:00"
close-reason: Mach-O writer finish path validated with external relocation symbols
blocks:
  - hoist-finish-coff-writer-7776ad8b
---

Context: src/object/macho.zig:159,194; cause: symbol index + load commands/sections TODO; fix: implement load commands, section table, symtab, strtab; deps: none; verification: emit Mach-O and link with ld
