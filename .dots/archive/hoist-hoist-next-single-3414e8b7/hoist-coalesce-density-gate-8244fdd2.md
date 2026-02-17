---
title: Coalesce density gate
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T18:21:36.875715+01:00\\\"\""
closed-at: "2026-02-17T18:39:02.876234+01:00"
close-reason: completed
---

Full context: src/codegen/compile.zig collectCoalescePairs scans all vcode instructions every compile. Cause: full scan overhead when move density is too low to pay off. Fix: add low-cost move-density gate and skip pair collection when below threshold.
