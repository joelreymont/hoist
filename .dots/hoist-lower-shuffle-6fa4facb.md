---
title: Lower shuffle
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T18:27:04.087294+01:00"
---

Context: src/ir/opcodes.zig:83; cause: shuffle opcode has no AArch64 lowering case; fix: add ISLE rules + lowering for dup/zip/uzp/trn/rev patterns; deps: Handle ISLE extractors; verification: zig build test
