---
title: Fix ELF Reloc Symbol Indices
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.573126+01:00"
blocks:
  - hoist-fix-obj-writers-75b5006b
---

Context: src/object/elf.zig:171; cause: sym_idx hardcoded 0; fix: resolve target symbols and assign indices; deps: Fix Object Writers; verification: unit test for reloc symbol index
