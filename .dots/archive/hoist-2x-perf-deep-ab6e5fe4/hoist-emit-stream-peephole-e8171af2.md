---
title: Emit stream peephole
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T19:21:15.581575+01:00\\\"\""
closed-at: "2026-02-21T19:57:01.152267+01:00"
close-reason: "discarded: repeat-9 regressions vs cfg-bitset baseline"
blocks:
  - hoist-cfg-liveness-bitset-d3a88f13
---

Context: src/codegen/compile.zig:2180-2275; cause: per-block copy + iterative peephole loops; fix: stream block slices with single-pass peephole window; deps:hoist-cfg-liveness-bitset-d3a88f13; verification: tests + repeat-9 gate.
