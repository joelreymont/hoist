---
title: Fix ELF Reloc Symbol Indices
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.457130+01:00"
---

Context: src/object/elf.zig:171; cause: sym_idx hardcoded 0; fix: resolve target symbols and assign indices; deps: hoist-fix-obj-writers-aace2da4; verification: unit test for reloc symbol index
