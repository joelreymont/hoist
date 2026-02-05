---
title: Lower shuffle
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.742883+01:00\\\"\""
closed-at: "2026-02-05T23:25:44.749984+01:00"
close-reason: Shuffle lowering tests added; fallback now uses TBL for non-special masks; ISLE result emit fixed.
blocks:
  - hoist-trap-fcvtzs-89921e7c
---

Context: src/ir/opcodes.zig:83; cause: shuffle opcode has no AArch64 lowering case; fix: add ISLE rules + lowering for dup/zip/uzp/trn/rev patterns; deps: Handle ISLE extractors; verification: zig build test
