---
title: Add ELF Section Layout
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.580467+01:00\""
closed-at: "2026-02-05T21:54:18.237294+01:00"
close-reason: ELF section layout is emitted and validated by finish tests
blocks:
  - hoist-fix-elf-reloc-0c013c4d
---

Context: src/object/elf.zig:191; cause: no section offsets/headers; fix: compute layout and emit section headers; deps: Fix ELF Reloc Symbol Indices; verification: llvm-readobj shows sections
