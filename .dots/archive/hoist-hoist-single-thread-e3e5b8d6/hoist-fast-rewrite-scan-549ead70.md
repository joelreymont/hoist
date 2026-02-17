---
title: Fast rewrite scan
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T17:42:02.618126+01:00\\\"\""
closed-at: "2026-02-17T17:48:31.809741+01:00"
close-reason: discarded (<5% retained key-metric gain)
blocks:
  - hoist-dense-liveness-map-ed60eafe
---

Full context: src/codegen/compile.zig:6689-6723 rewrites every instruction recursively after regalloc. Cause: generic rewriteValue recursion spends time on instructions that do not contain vregs. Fix: add cheap per-inst fast path and specialized rewrite for hot instruction forms; keep semantics identical and verify with tests+gate.
