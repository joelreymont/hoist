---
title: Regalloc event queues
status: open
priority: 1
issue-type: task
created-at: "2026-02-21T19:21:15.591804+01:00"
blocks:
  - hoist-emit-stream-peephole-e8171af2
---

Context: src/regalloc/linear_scan.zig:343-573; cause: active list scan/memmove/orderedRemove costs; fix: class-partitioned expire/spill queues replacing repeated scans; deps:hoist-emit-stream-peephole-e8171af2; verification: regalloc tests + repeat-9 gate.
