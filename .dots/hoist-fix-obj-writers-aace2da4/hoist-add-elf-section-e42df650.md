---
title: Add ELF Section Layout
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.463185+01:00"
---

Context: src/object/elf.zig:191; cause: no section offsets/headers; fix: compute layout and emit section headers; deps: hoist-fix-elf-reloc-50ff441f; verification: llvm-readobj shows sections
