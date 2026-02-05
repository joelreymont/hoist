---
title: Peephole redundant loads
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.771123+01:00\""
closed-at: "2026-02-06T00:02:34.916858+01:00"
close-reason: Added safe non-adjacent redundant-load elimination with tests
blocks:
  - hoist-peephole-dead-moves-10bef64e
---

Context: src/codegen/peephole.zig:131-139; cause: redundant load elimination not implemented; fix: add alias-aware load redundancy pass; deps: none; verification: zig build test
