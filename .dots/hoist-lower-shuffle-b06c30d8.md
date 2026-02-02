---
title: Lower shuffle
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.742883+01:00"
blocks:
  - hoist-trap-fcvtzs-89921e7c
---

Context: src/ir/opcodes.zig:83; cause: shuffle opcode has no AArch64 lowering case; fix: add ISLE rules + lowering for dup/zip/uzp/trn/rev patterns; deps: Handle ISLE extractors; verification: zig build test
