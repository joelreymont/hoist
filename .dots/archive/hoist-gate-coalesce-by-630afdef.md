---
title: Gate coalesce by complexity
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T16:09:20.250955+01:00\""
closed-at: "2026-02-17T16:10:57.126388+01:00"
close-reason: "discarded: no >=5% single-thread gains in A/B; reverted complexity gate"
---

src/codegen/compile.zig allocateRegisters(): collectCoalescePairs only for sufficiently complex functions to reduce regalloc time on small functions. Validate A/B and keep only if >=5% positive.
