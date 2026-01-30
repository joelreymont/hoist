---
title: Finish ELF writer
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:25:54.456345+01:00"
---

Context: src/object/elf.zig:174,219; cause: symbol index resolution + section/symtab emission TODO; fix: implement section headers, symtab, strtab, relocation writes; deps: none; verification: emit ELF and link with ld
