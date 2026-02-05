---
title: Finish ELF writer
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.863024+01:00\""
closed-at: "2026-02-05T21:54:24.659397+01:00"
close-reason: ELF writer emits linkable layout with relocation/symbol indices
blocks:
  - hoist-obj-emission-ad51d2ad
---

Context: src/object/elf.zig:174,219; cause: symbol index resolution + section/symtab emission TODO; fix: implement section headers, symtab, strtab, relocation writes; deps: none; verification: emit ELF and link with ld
