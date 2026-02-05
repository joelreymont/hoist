---
title: Fix COFF Reloc Symbol Indices
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.594810+01:00\""
closed-at: "2026-02-05T21:50:43.594844+01:00"
close-reason: COFF relocations now resolve symbol indices via ensureSymbol
blocks:
  - hoist-add-elf-symtab-c233787d
---

Context: src/object/coff.zig:160; cause: sym_idx hardcoded 0; fix: resolve target symbols and assign indices; deps: Fix Object Writers; verification: objdump --syms shows relocs
