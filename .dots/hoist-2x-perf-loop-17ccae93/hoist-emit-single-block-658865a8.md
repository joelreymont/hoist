---
title: emit single-block label fast
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T21:05:18.627374+01:00\\\"\""
closed-at: "2026-02-21T21:20:14.520302+01:00"
close-reason: "discarded: repeat-9 regressions (large/fib)"
---

Context: emitAArch64WithAllocation builds vcode_to_ir_blocks map and registers labels for all blocks; fix: single-block fast path avoiding reverse map/hash operations.
