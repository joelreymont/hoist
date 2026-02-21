---
title: CFG liveness bitset 2
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T19:21:15.571095+01:00\\\"\""
closed-at: "2026-02-21T19:52:28.048457+01:00"
close-reason: "discarded: repeat-9 gate regressions vs cfg-bitset baseline"
blocks:
  - hoist-cfg-liveness-bitset-8560996b
---

Context: src/regalloc/liveness.zig:474-608; cause: second pass rebuild uses hash map; fix: convert range synthesis to dense table aligned with bitset pass; deps:hoist-cfg-liveness-bitset-8560996b; verification: tests + repeat-9 gate.
