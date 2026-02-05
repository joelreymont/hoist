---
title: Fix ELF Reloc Symbol Indices
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.573126+01:00\""
closed-at: "2026-02-05T21:51:32.144818+01:00"
close-reason: Added external-reloc index coverage for ELF symbol refs
blocks:
  - hoist-fix-obj-writers-75b5006b
---

Context: src/object/elf.zig:171; cause: sym_idx hardcoded 0; fix: resolve target symbols and assign indices; deps: Fix Object Writers; verification: unit test for reloc symbol index
