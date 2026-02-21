---
title: Regalloc event queues
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T19:21:15.591804+01:00\\\"\""
closed-at: "2026-02-21T20:00:53.697034+01:00"
close-reason: "discarded: no >=5% retained wins in repeat-9 gate"
blocks:
  - hoist-emit-stream-peephole-e8171af2
---

Context: src/regalloc/linear_scan.zig:343-573; cause: active list scan/memmove/orderedRemove costs; fix: class-partitioned expire/spill queues replacing repeated scans; deps:hoist-emit-stream-peephole-e8171af2; verification: regalloc tests + repeat-9 gate.
