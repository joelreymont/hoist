---
title: Fix Mach-O Reloc Symbol Indices
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.608539+01:00\""
closed-at: "2026-02-05T21:52:34.998660+01:00"
close-reason: Added external-reloc index coverage for Mach-O writer output
blocks:
  - hoist-add-coff-section-729c5f12
---

Context: src/object/macho.zig:156; cause: sym_idx hardcoded 0; fix: resolve target symbols and assign indices; deps: Fix Object Writers; verification: otool -Iv
