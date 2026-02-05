---
title: Object emission
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.856581+01:00\""
closed-at: "2026-02-05T21:55:01.056005+01:00"
close-reason: ELF/COFF/Mach-O writers emit sections, symbols, strings, and relocs
blocks:
  - hoist-implement-s390x-vreg-8d42efbf
---

Context: src/object/{elf,coff,macho}.zig; cause: section/symtab emission TODO; fix: complete object writers; deps: none; verification: object writer tests + linkable artifacts
