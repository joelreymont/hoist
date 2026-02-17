---
title: Skip coalesce in fast mode
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T15:09:46.875969+01:00\\\"\""
closed-at: "2026-02-17T15:12:24.312828+01:00"
close-reason: "Discarded: A/B results were mostly <5% gains; reverted change."
---

Full context: src/codegen/compile.zig always runs collectCoalescePairs before linear scan, including target.optimize=false fast-compilation mode where move-quality optimization is not required; cause is unconditional coalesce pass overhead inside regalloc stage; fix by skipping coalesce when optimization is disabled; proof via same-tree A/B logs and keep only if >=5% positive gains.
