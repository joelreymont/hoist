---
title: Fix Mach-O Reloc Symbol Indices
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.608539+01:00"
blocks:
  - hoist-add-coff-section-729c5f12
---

Context: src/object/macho.zig:156; cause: sym_idx hardcoded 0; fix: resolve target symbols and assign indices; deps: Fix Object Writers; verification: otool -Iv
