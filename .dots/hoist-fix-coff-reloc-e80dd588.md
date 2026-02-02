---
title: Fix COFF Reloc Symbol Indices
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.594810+01:00"
blocks:
  - hoist-add-elf-symtab-c233787d
---

Context: src/object/coff.zig:160; cause: sym_idx hardcoded 0; fix: resolve target symbols and assign indices; deps: Fix Object Writers; verification: objdump --syms shows relocs
