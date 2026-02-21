---
title: CFG liveness bitset 2
status: open
priority: 1
issue-type: task
created-at: "2026-02-21T19:21:15.571095+01:00"
blocks:
  - hoist-cfg-liveness-bitset-8560996b
---

Context: src/regalloc/liveness.zig:474-608; cause: second pass rebuild uses hash map; fix: convert range synthesis to dense table aligned with bitset pass; deps:hoist-cfg-liveness-bitset-8560996b; verification: tests + repeat-9 gate.
