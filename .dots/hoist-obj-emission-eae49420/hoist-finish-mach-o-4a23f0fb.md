---
title: Finish Mach-O writer
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:26:00.681203+01:00"
---

Context: src/object/macho.zig:159,194; cause: symbol index + load commands/sections TODO; fix: implement load commands, section table, symtab, strtab; deps: none; verification: emit Mach-O and link with ld
