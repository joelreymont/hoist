---
title: Add ELF Section Layout
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.580467+01:00"
blocks:
  - hoist-fix-elf-reloc-0c013c4d
---

Context: src/object/elf.zig:191; cause: no section offsets/headers; fix: compute layout and emit section headers; deps: Fix ELF Reloc Symbol Indices; verification: llvm-readobj shows sections
