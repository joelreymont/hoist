---
title: ELF writer
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:57:08.139622+01:00\\\"\""
closed-at: "2026-02-04T17:46:03.688104+01:00"
close-reason: Implemented ELF layout/symtab/rela + tests; zig build test fails in ISLE codegen (dup aliases, pointless discards).
blocks:
  - hoist-obj-writers-1fd57da5
---

File: src/object/elf.zig:219; cause: section headers/symtab/strtab/rela TODO; fix: implement layout, symbol table, reloc entries; why: valid ELF output.
